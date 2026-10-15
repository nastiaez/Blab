import { compactPlan, expandCompactResponse } from "./compact_request.ts";
import { hasParticipantFormDifference } from "./participant_forms.ts";
import {
  isProtectedLiteralMessage,
  LANG_NAMES,
  parseProviderResult,
  preservesLiteralCharacters,
  type ProviderCredential,
  type TranslationResult,
  unsupportedSourceScript,
  wordGlossMetadataNeedsRepair,
} from "./contract.ts";
import { SINGLE_CALL_POLICY } from "./rulebook.ts";
import { fetchChatCompletion, type FetchLike } from "./provider.ts";

export type PreparedViewer = {
  key: string;
  messageId: string;
  text: string;
  sourceHash: string;
  targetLang: string;
  interfaceLang: string;
  context?: unknown;
  formContext?: unknown;
};

export function boundedContext(raw: unknown): unknown[] {
  if (!Array.isArray(raw)) return [];
  const chosen: unknown[] = [];
  let bytes = 0;
  for (
    const entry of raw.slice(-SINGLE_CALL_POLICY.contextMessages).reverse()
  ) {
    if (!entry || typeof entry !== "object") continue;
    const v = entry as Record<string, unknown>;
    if (
      typeof v.text !== "string" ||
      !["viewer", "partner"].includes(String(v.speaker))
    ) continue;
    const safe = {
      speaker: v.speaker,
      text: v.text,
      isReply: v.isReply === true,
    };
    const cost = new TextEncoder().encode(JSON.stringify(safe)).length;
    if (bytes + cost > SINGLE_CALL_POLICY.contextUtf8Bytes) continue;
    bytes += cost;
    chosen.unshift(safe);
  }
  return chosen;
}

export function singleCallRequest(viewers: PreparedViewer[]) {
  if (
    !viewers.length || viewers.length > 4 ||
    new Set(viewers.map((v) => v.key)).size !== viewers.length ||
    viewers.some((v) =>
      v.messageId !== viewers[0].messageId || v.text !== viewers[0].text ||
      v.sourceHash !== viewers[0].sourceHash || !(v.targetLang in LANG_NAMES) ||
      !(v.interfaceLang in LANG_NAMES)
    )
  ) {
    throw new Error("invalid_message_batch");
  }
  return compactPlan(viewers).request;
}

export async function generateMessageOnce(
  viewers: PreparedViewer[],
  credential: ProviderCredential,
  fetchImpl?: FetchLike,
): Promise<Record<string, TranslationResult>> {
  const request = singleCallRequest(viewers);
  const source = viewers[0].text;
  const unsupported = unsupportedSourceScript(source);
  if (unsupported || isProtectedLiteralMessage(source)) {
    return Object.fromEntries(
      viewers.map(
        (v) => [v.key, {
          mode: unsupported ? "translation" : "none",
          sourceLang: unsupported ? "other" : v.targetLang,
          translation: source,
          interfaceText: source,
          explanation: null,
          confidence: null,
          tokens: [],
          formAlternatives: null,
        }],
      ),
    ) as Record<string, TranslationResult>;
  }
  const response = await fetchChatCompletion(credential, request, {
    fetchImpl,
    timeoutMs: SINGLE_CALL_POLICY.timeoutMs,
  });
  if (!response.ok) throw new Error(`provider_http_${response.status}`);
  const payload = await response.json();
  if (payload.choices?.[0]?.finish_reason === "length") {
    throw new Error("provider_output_truncated");
  }
  const raw = expandCompactResponse(
    JSON.parse(payload.choices?.[0]?.message?.content ?? "null"),
    viewers,
    compactPlan(viewers),
  );
  if (
    !raw || typeof raw !== "object" || Array.isArray(raw) ||
    Object.keys(raw).length !== viewers.length
  ) throw new Error("invalid_viewer_results");
  const results: Record<string, TranslationResult> = {};
  for (const v of viewers) {
    if (!Object.hasOwn(raw, v.key)) throw new Error("missing_viewer_result");
    // Deterministically expand fragment-only form tokens from the already
    // returned base sentence; this never requests or invents a gloss.
    const rawResult = raw[v.key];
    const forms = rawResult.formAlternatives;
    if (
      forms && typeof forms.before === "string" &&
      typeof forms.feminine === "string" &&
      typeof forms.masculine === "string" &&
      typeof forms.after === "string" && !hasParticipantFormDifference(
        v.targetLang,
        forms.before + forms.feminine + forms.after,
        forms.before + forms.masculine + forms.after,
      )
    ) {
      rawResult.formAlternatives = null;
    } else if (forms && Array.isArray(rawResult.tokens)) {
      const tokens = rawResult.tokens as Array<{ text: string }>;
      let offset = 0;
      const before: unknown[] = [], after: unknown[] = [];
      for (const token of tokens) {
        const end = offset + token.text.length;
        if (end <= forms.before.length) before.push(token);
        if (offset >= rawResult.translation.length - forms.after.length) {
          after.push(token);
        }
        offset = end;
      }
      for (const form of ["feminine", "masculine"]) {
        const ft = forms[`${form}Tokens`];
        if (
          Array.isArray(ft) && ft.map((t: { text: string }) =>
              t.text
            ).join("") === forms[form] &&
          (before as Array<{ text: string }>).map((t) => t.text).join("") ===
            forms.before &&
          (after as Array<{ text: string }>).map((t) => t.text).join("") ===
            forms.after
        ) {
          forms[`${form}Tokens`] = [...before, ...ft, ...after];
        }
      }
    }
    // The storage contract uses a feminine canonical sentence. If the model
    // supplied the masculine base plus both complete forms, normalize using
    // only its own validated alternative, without another generation.
    if (
      forms && rawResult.formAlternatives &&
      rawResult.translation === forms.before + forms.masculine + forms.after &&
      Array.isArray(forms.feminineTokens) &&
      forms.feminineTokens.map((t: { text: string }) => t.text).join("") ===
        forms.before + forms.feminine + forms.after
    ) {
      rawResult.translation = forms.before + forms.feminine + forms.after;
      rawResult.tokens = forms.feminineTokens;
    }
    const r = parseProviderResult(
      JSON.stringify(raw[v.key]),
      source,
      v.targetLang,
      v.interfaceLang,
    );
    if (
      !r || r.sourceClassificationConflict || !r.interfaceText.trim() ||
      !preservesLiteralCharacters(source, r.translation) ||
      !preservesLiteralCharacters(source, r.interfaceText)
    ) {
      throw new Error("invalid_translation_result");
    }
    if (
      r.sourceLang !== "other" &&
      (r.tokens.length === 0 ||
        wordGlossMetadataNeedsRepair(r, v.targetLang, v.interfaceLang, source))
    ) {
      throw new Error("invalid_word_help");
    }
    if (
      v.targetLang !== v.interfaceLang && r.interfaceText === r.translation &&
      (source.match(/\p{L}+/gu)?.length ?? 0) > 1 && r.sourceLang !== "other"
    ) {
      throw new Error("copied_language_lane");
    }
    if (raw[v.key].formAlternatives && !r.formAlternatives) {
      throw new Error("invalid_form_alternatives");
    }
    if (r.formAlternatives) {
      const f = r.formAlternatives;
      const ft = f.feminineTokens, mt = f.masculineTokens;
      if (ft && mt) {
        let start = 0, end = 0;
        while (
          start < Math.min(ft.length, mt.length) &&
          ft[start].text === mt[start].text
        ) start++;
        while (
          end < Math.min(ft.length, mt.length) - start &&
          ft[ft.length - 1 - end].text === mt[mt.length - 1 - end].text
        ) end++;
        if (start < ft.length - end && start < mt.length - end) {
          f.before = ft.slice(0, start).map((t) => t.text).join("");
          f.after = end ? ft.slice(-end).map((t) => t.text).join("") : "";
          f.feminine = ft.slice(start, ft.length - end).map((t) => t.text).join(
            "",
          );
          f.masculine = mt.slice(start, mt.length - end).map((t) => t.text)
            .join("");
        }
      }
      r.formAlternatives.subjectRole = r.formAlternatives.subjectIsViewer
        ? ((v.formContext as { messageAuthor?: string })?.messageAuthor ===
            "viewer"
          ? "author"
          : "recipient")
        : ((v.formContext as { messageAuthor?: string })?.messageAuthor ===
            "viewer"
          ? "recipient"
          : "author");
    }
    results[v.key] = r;
  }
  return results;
}
