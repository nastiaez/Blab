import { LANG_NAMES, TRANSLATION_RESPONSE_FORMAT } from "./contract.ts";
import { COMPACT_TRANSLATION_RULES, SINGLE_CALL_POLICY } from "./rulebook.ts";
import type { PreparedViewer } from "./single_call.ts";

type ContextLine = { sender: "sender" | "recipient"; message: string };
type Context = { previous?: ContextLine[]; reply_to?: ContextLine };
type Sentence = { id: string; language: string; tone: string; context: string };
type Help = { id: string; sentence: string; words: string; meanings: string };
type Binding = { sentence: string; secondary: string; help: string };
const object = (properties: Record<string, unknown>) => ({
  type: "object",
  additionalProperties: false,
  properties,
  required: Object.keys(properties),
});
const base = TRANSLATION_RESPONSE_FORMAT.json_schema.schema.properties;
const tokenArray = {
  ...base.tokens,
  minItems: 0,
  description:
    "Token text is from the referenced sentence in words language, NOT meanings language. Every content word/term (including URLs/handles/tags) needs a short gloss in meanings language. Spaces/punctuation/emoji are noncontent with null gloss. Concatenate to the entire sentence exactly.",
};
// This schema is identical for every language combination and message.
export const COMPACT_RESPONSE_FORMAT = {
  type: "json_schema",
  json_schema: {
    name: "blab_translation_bundle",
    strict: true,
    schema: object({
      sentences: {
        type: "array",
        items: object({
          id: { type: "string" },
          sourceLang: base.sourceLang,
          mode: {
            ...base.mode,
            description:
              "translation if source differs; correction for a genuine same-language error; none otherwise, retaining trimmed original exactly.",
          },
          text: {
            type: "string",
            description:
              "Full natural sentence in the requested language. Feminine base when forms exist.",
          },
          confidence: {
            ...base.confidence,
            description: "Correction confidence only; null otherwise.",
          },
          forms: {
            type: ["object", "null"],
            additionalProperties: false,
            properties: {
              before: { type: "string" },
              feminine: { type: "string" },
              masculine: { type: "string" },
              after: { type: "string" },
              subject: { type: "string", enum: ["sender", "recipient"] },
              suggestedForm: base.formAlternatives.properties.suggestedForm,
            },
            required: [
              "before",
              "feminine",
              "masculine",
              "after",
              "subject",
              "suggestedForm",
            ],
            description:
              "Only mode=translation participant gender differences; null for none/correction. before+feminine+after equals text; masculine replaces the complete affected fragment.",
          },
        }),
      },
      help: {
        type: "array",
        items: object({
          id: { type: "string" },
          explanation: {
            ...base.explanation,
            description:
              "Brief explanation in the requested meanings language only for correction, otherwise null.",
          },
          tokens: tokenArray,
          feminineTokens: {
            ...tokenArray,
            description:
              "Entire feminine sentence tokens when forms exist, otherwise empty.",
          },
          masculineTokens: {
            ...tokenArray,
            description:
              "Entire masculine sentence tokens when forms exist, otherwise empty.",
          },
        }),
      },
    }),
  },
};

function contextFor(v: PreparedViewer): Context {
  const f = (v.formContext ?? {}) as Record<string, unknown>;
  const raw = Array.isArray(v.context) ? v.context : [];
  let bytes = 0;
  const chosen: Array<ContextLine & { reply: boolean }> = [];
  // Reserve the explicit quote first, then the nearest context, within one budget.
  const eligible = raw.slice(-SINGLE_CALL_POLICY.contextMessages).filter((x) =>
    x && typeof x.text === "string" && ["viewer", "partner"].includes(x.speaker)
  );
  const priority = [...eligible].reverse().sort((a, b) =>
    Number(b.isReply === true) - Number(a.isReply === true)
  );
  for (const entry of priority) {
    const line = {
      sender: (entry.speaker === f.messageAuthor
        ? "sender"
        : "recipient") as ContextLine["sender"],
      message: entry.text,
      reply: entry.isReply === true,
    };
    const cost = new TextEncoder().encode(JSON.stringify(line)).length;
    if (bytes + cost > SINGLE_CALL_POLICY.contextUtf8Bytes) {
      continue;
    }
    bytes += cost;
    chosen.push(line);
  }
  const lines = eligible.map((entry) =>
    chosen.find((line) =>
      line.message === entry.text &&
      line.sender ===
        (entry.speaker === f.messageAuthor ? "sender" : "recipient") &&
      line.reply === (entry.isReply === true)
    )
  ).filter((x) => x !== undefined);
  const previous = lines.filter((x) => !x.reply).map(({ sender, message }) => ({
    sender,
    message,
  }));
  const quote = lines.find((x) => x.reply);
  return {
    ...(previous.length ? { previous } : {}),
    ...(quote
      ? { reply_to: { sender: quote.sender, message: quote.message } }
      : {}),
  };
}

export function compactPlan(viewers: PreparedViewer[]) {
  const contexts: Record<string, Context> = {};
  const contextKeys = new Map<string, string>();
  const sentences = new Map<string, Sentence>();
  const help = new Map<string, Help>();
  const bindings: Record<string, Binding> = {};
  let sender: unknown, recipient: unknown;
  for (const v of [...viewers].sort((a, b) => a.key.localeCompare(b.key))) {
    const f = (v.formContext ?? {}) as Record<string, unknown>;
    const author = f.messageAuthor === "partner" ? f.partnerName : f.viewerName;
    const receiver = f.messageAuthor === "partner"
      ? f.viewerName
      : f.partnerName;
    if (
      sender !== undefined && author !== undefined && sender !== author ||
      recipient !== undefined && receiver !== undefined &&
        recipient !== receiver
    ) throw new Error("inconsistent_participants");
    sender ??= author;
    recipient ??= receiver;
    const context = contextFor(v);
    const serialized = JSON.stringify(context);
    let contextId = contextKeys.get(serialized);
    if (!contextId) {
      contextId = `c${contextKeys.size}`;
      contextKeys.set(serialized, contextId);
      contexts[contextId] = context;
    }
    const tone = f.tone === "respectful" ? "respectful" : "informal";
    const sentence = (lang: string) => {
      const id = `${lang}_${tone}_${contextId}`;
      sentences.set(id, {
        id,
        language: LANG_NAMES[lang],
        tone,
        context: contextId!,
      });
      return id;
    };
    const primary = sentence(v.targetLang),
      secondary = sentence(v.interfaceLang);
    const helpId = `${primary}_${v.interfaceLang}`;
    help.set(helpId, {
      id: helpId,
      sentence: primary,
      words: LANG_NAMES[v.targetLang],
      meanings: LANG_NAMES[v.interfaceLang],
    });
    bindings[v.key] = { sentence: primary, secondary, help: helpId };
  }
  const requested = {
    sentences: [...sentences.values()].sort((a, b) => a.id.localeCompare(b.id)),
    help: [...help.values()].sort((a, b) => a.id.localeCompare(b.id)),
  };
  const nonemptyContexts = Object.fromEntries(
    Object.entries(contexts).filter(([, c]) => Object.keys(c).length),
  );
  return {
    bindings,
    requested,
    request: {
      messages: [
        {
          role: "system",
          content: COMPACT_TRANSLATION_RULES + "\nRequested outputs: " +
            JSON.stringify(requested),
        },
        {
          role: "user",
          content: JSON.stringify({
            ...(sender ? { sender } : {}),
            ...(recipient ? { recipient } : {}),
            ...(Object.keys(nonemptyContexts).length
              ? { contexts: nonemptyContexts }
              : {}),
            message: viewers[0].text,
          }),
        },
      ],
      temperature: 0,
      max_tokens: Math.min(
        SINGLE_CALL_POLICY.maxOutputTokens,
        Math.max(2500, viewers[0].text.length * 30) * help.size,
      ),
      response_format: COMPACT_RESPONSE_FORMAT,
    },
  };
}

export function expandCompactResponse(
  raw: unknown,
  viewers: PreparedViewer[],
  plan: ReturnType<typeof compactPlan>,
): Record<string, any> {
  const data = raw as {
    sentences?: Array<Record<string, any>>;
    help?: Array<Record<string, any>>;
  } | null;
  const index = (rows: unknown, ids: string[]) => {
    if (!Array.isArray(rows) || rows.length !== ids.length) {
      throw new Error("invalid_output_count");
    }
    const result = new Map<string, Record<string, any>>();
    for (const row of rows) {
      if (
        !row || typeof row !== "object" || !ids.includes(row.id) ||
        result.has(row.id)
      ) throw new Error("invalid_output_id");
      result.set(row.id, row);
    }
    return result;
  };
  const sentences = index(
    data?.sentences,
    plan.requested.sentences.map((s) => s.id),
  );
  const help = index(data?.help, plan.requested.help.map((h) => h.id));
  return Object.fromEntries(viewers.map((v) => {
    const b = plan.bindings[v.key],
      s = sentences.get(b.sentence)!,
      secondary = sentences.get(b.secondary)!,
      h = help.get(b.help)!;
    if (s.sourceLang !== secondary.sourceLang) {
      throw new Error("inconsistent_source_language");
    }
    // Reuse already-returned complete form metadata when the provider omits
    // the duplicate base token array. No new words or glosses are invented.
    const tokens = Array.isArray(h.tokens) && h.tokens.length
      ? h.tokens
      : [h.feminineTokens, h.masculineTokens].find((items) =>
        Array.isArray(items) && items.length && items.every((t) =>
          t && typeof t.text === "string"
        ) &&
        items.map((t) => t.text).join("") === s.text
      ) ?? h.tokens;
    const f = (v.formContext ?? {}) as Record<string, unknown>;
    const isAuthor = f.messageAuthor !== "partner";
    if (s.forms && !["sender", "recipient"].includes(s.forms.subject)) {
      throw new Error("invalid_form_subject");
    }
    const subjectIsViewer = s.forms?.subject === "sender"
      ? isAuthor
      : !isAuthor;
    return [
      v.key,
      structuredClone({
        mode: s.mode,
        sourceLang: s.sourceLang,
        translation: s.mode === "none" && s.sourceLang === v.targetLang
          ? v.text.trim()
          : s.text,
        interfaceText: secondary.text,
        explanation: h.explanation,
        confidence: s.confidence,
        tokens,
        formAlternatives: s.forms && s.sourceLang !== v.targetLang
          ? {
            before: s.forms.before,
            feminine: s.forms.feminine,
            masculine: s.forms.masculine,
            after: s.forms.after,
            subjectIsViewer,
            subjectName: (subjectIsViewer ? f.viewerName : f.partnerName) ??
              (s.forms.subject === "sender" ? "sender" : "recipient"),
            suggestedForm: s.forms.suggestedForm,
            feminineTokens: h.feminineTokens,
            masculineTokens: h.masculineTokens,
          }
          : null,
      }),
    ];
  }));
}
