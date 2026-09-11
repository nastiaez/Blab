// Server-authoritative real-chat translator. The client supplies only a
// message ID. Postgres validates the caller and derives source text and target
// language before quota-limited provider work begins.
//
// Deploy: supabase functions deploy translate-message
// OPEN_ROUTER_KEY remains server-side.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  applyConfirmedFormAudit,
  correctionNeedsRetry,
  directSubjectRole,
  FORM_AUDIT_RESPONSE_FORMAT,
  formAuditSystemPrompt,
  type FormParticipantContext,
  genderedAmbiguityNeedsRetry,
  INTERFACE_RESPONSE_FORMAT,
  interfaceOutputNeedsRetry,
  interfaceRepairSystemPrompt,
  LANG_NAMES,
  missingFormAlternativesNeedsAudit,
  normalizeFormSubject,
  OPENROUTER_PROVIDER,
  parseFormAuditResult,
  parseProviderResult,
  type ProviderCredential,
  providerCredentials,
  providerMessages,
  providerResultFailureReason,
  TRANSLATION_RESPONSE_FORMAT,
  type TranslationContextMessage,
  translationNeedsRetry,
  validateRequest,
} from "./contract.ts";
import { workerJobId } from "../prepare-message-jobs/contract.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BLAB_ENV = Deno.env.get("BLAB_ENV");
const OPEN_ROUTER_KEY = Deno.env.get("OPEN_ROUTER_KEY");
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const OPENROUTER_MODEL = Deno.env.get("OPENROUTER_MODEL");
const OPENAI_MODEL = Deno.env.get("OPENAI_MODEL");
const OPENROUTER_PROVIDER_POLICY = Deno.env.get("OPENROUTER_PROVIDER_POLICY");
const CACHE_CONTRACT_VERSION = "automatic-forms-v2";
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

function providerName(credential: ProviderCredential): string {
  return credential.provider === "openrouter" ? "OpenRouter" : "OpenAI";
}

function chatCompletionEndpoint(credential: ProviderCredential): string {
  return credential.provider === "openrouter"
    ? "https://openrouter.ai/api/v1/chat/completions"
    : "https://api.openai.com/v1/chat/completions";
}

function chatCompletionModel(credential: ProviderCredential): string {
  return credential.model;
}

async function fetchChatCompletion(
  credential: ProviderCredential,
  body: Record<string, unknown>,
): Promise<Response> {
  return await fetch(chatCompletionEndpoint(credential), {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${credential.apiKey}`,
    },
    body: JSON.stringify({
      ...body,
      model: chatCompletionModel(credential),
      ...(credential.provider === "openrouter" &&
          credential.useOpenRouterProviderPolicy
        ? { provider: OPENROUTER_PROVIDER }
        : {}),
    }),
  });
}

async function repairInterfaceText(
  credential: ProviderCredential,
  learningText: string,
  targetLang: string,
  interfaceLang: string,
): Promise<string | null> {
  let response: Response;
  try {
    response = await fetchChatCompletion(credential, {
      temperature: 0,
      max_completion_tokens: 4000,
      response_format: INTERFACE_RESPONSE_FORMAT,
      messages: [
        {
          role: "system",
          content: interfaceRepairSystemPrompt(targetLang, interfaceLang),
        },
        { role: "user", content: learningText },
      ],
    });
  } catch {
    return null;
  }
  if (!response.ok) return null;

  let payload: unknown;
  try {
    payload = await response.json();
  } catch {
    return null;
  }
  const content = (payload as {
    choices?: Array<{ message?: { content?: unknown } }>;
  })?.choices?.[0]?.message?.content;
  if (typeof content !== "string") return null;
  const firstBrace = content.indexOf("{");
  const lastBrace = content.lastIndexOf("}");
  if (firstBrace < 0 || lastBrace <= firstBrace) return null;
  try {
    const parsed = JSON.parse(content.slice(firstBrace, lastBrace + 1));
    const interfaceText = parsed?.interfaceText;
    return typeof interfaceText === "string" && interfaceText.trim().length > 0
      ? interfaceText
      : null;
  } catch {
    return null;
  }
}

async function auditGrammaticalForm(
  credential: ProviderCredential,
  sourceText: string,
  translatedText: string,
  sourceLang: string,
  targetLang: string,
  interfaceLang: string,
  formContext: FormParticipantContext,
) {
  const directRole = directSubjectRole(sourceText, sourceLang);
  const directViewer = directRole === "author"
    ? formContext.messageAuthor === "viewer"
    : formContext.messageAuthor !== "viewer";
  const subjectHint = directRole
    ? `\nThis direct sentence concerns ${
      directViewer ? formContext.viewerName : formContext.partnerName
    }. If agreement changes, subjectIsViewer must be ${directViewer}; suggest a form for that person only.`
    : "";
  let response: Response;
  try {
    response = await fetchChatCompletion(credential, {
      temperature: 0,
      max_completion_tokens: 4000,
      response_format: FORM_AUDIT_RESPONSE_FORMAT,
      messages: [
        {
          role: "system",
          content: formAuditSystemPrompt(
            sourceLang,
            targetLang,
            interfaceLang,
            formContext,
          ),
        },
        {
          role: "user",
          content:
            `Source message:\n${sourceText}\n\nCandidate translation:\n${translatedText}${subjectHint}`,
        },
      ],
    });
  } catch {
    return null;
  }
  if (!response.ok) return null;

  let payload: unknown;
  try {
    payload = await response.json();
  } catch {
    return null;
  }
  const content = (payload as {
    choices?: Array<{ message?: { content?: unknown } }>;
  })?.choices?.[0]?.message?.content;
  return typeof content === "string" ? parseFormAuditResult(content) : null;
}

function json(
  body: unknown,
  status = 200,
  headers: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json",
      ...headers,
    },
  });
}

function formContextFrom(value: unknown): FormParticipantContext | undefined {
  if (typeof value !== "object" || value === null) return undefined;
  const raw = value as Record<string, unknown>;
  const isForm = (form: unknown): form is "feminine" | "masculine" | null =>
    form === "feminine" || form === "masculine" || form === null;
  if (
    typeof raw.viewerName !== "string" ||
    typeof raw.partnerName !== "string" ||
    (raw.messageAuthor !== "viewer" && raw.messageAuthor !== "partner") ||
    !isForm(raw.viewerForm) ||
    !isForm(raw.partnerForm) ||
    (raw.tone !== "informal" && raw.tone !== "respectful")
  ) return undefined;
  return {
    viewerName: raw.viewerName,
    partnerName: raw.partnerName,
    messageAuthor: raw.messageAuthor,
    viewerForm: raw.viewerForm,
    partnerForm: raw.partnerForm,
    tone: raw.tone,
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return json({ error: "authentication_required" }, 401);
  }

  let body: { messageId?: unknown; forceRefresh?: unknown; jobId?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const internalJobId = workerJobId(body);
  const isWorker = internalJobId !== null &&
    authHeader === `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`;
  let messageId: string;
  let requesterId: string | null = null;
  let preparedData: unknown;
  let preparedError: unknown;
  if (isWorker) {
    const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const response = await admin.rpc("request_message_translation_job", {
      p_job_id: internalJobId,
    });
    preparedData = response.data;
    preparedError = response.error;
    const preparedRecord = preparedData as Record<string, unknown> | null;
    messageId = typeof preparedRecord?.messageId === "string"
      ? preparedRecord.messageId
      : "";
    requesterId = typeof preparedRecord?.requesterId === "string"
      ? preparedRecord.requesterId
      : null;
  } else {
    const validation = validateRequest(body);
    if ("error" in validation) return json({ error: validation.error }, 400);
    messageId = validation.request.messageId;
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: userError } = await userClient.auth
      .getUser();
    if (userError || !userData.user) {
      return json({ error: "authentication_required" }, 401);
    }
    requesterId = userData.user.id;
    const forceRefresh = body.forceRefresh === true;
    const response = await userClient.rpc(
      forceRefresh
        ? "request_message_translation_fresh"
        : "request_message_translation",
      { p_message_id: messageId },
    );
    preparedData = response.data;
    preparedError = response.error;
  }
  if (
    preparedError || typeof preparedData !== "object" || preparedData === null
  ) {
    console.error("translation prepare failed");
    return json({ error: "translation_unavailable" }, 500);
  }
  const prepared = preparedData as Record<string, unknown>;
  // "no_aid_needed": normal-mode caller, message already in a language they
  // know. Postgres answers with the authored text and aid mode "none"; no
  // provider call, no cache write.
  if (prepared.status === "cached" || prepared.status === "no_aid_needed") {
    return json({
      translation: prepared.translation,
      interfaceText: prepared.interfaceText,
      mode: prepared.mode,
      sourceLang: prepared.sourceLang,
      interfaceLang: prepared.interfaceLang,
      explanation: prepared.explanation,
      confidence: prepared.confidence,
      tokens: prepared.tokens,
      formAlternatives: prepared.formAlternatives,
    });
  }
  if (prepared.status === "rate_limited") {
    const retryAfter = typeof prepared.retryAfterSeconds === "number"
      ? Math.max(1, Math.ceil(prepared.retryAfterSeconds))
      : 60;
    return json(
      { error: "translation_limit_reached", retryAfterSeconds: retryAfter },
      429,
      { "Retry-After": String(retryAfter) },
    );
  }
  if (prepared.status === "stale") {
    return json({ error: "translation_stale" }, 409);
  }
  if (prepared.status === "forbidden" || prepared.status === "not_eligible") {
    return json({ error: "translation_not_allowed" }, 403);
  }

  const text = prepared.text;
  const sourceLang = prepared.sourceLang;
  const targetLang = prepared.targetLang;
  const interfaceLang = prepared.interfaceLang;
  const sourceHash = prepared.sourceHash;
  const rawContext = prepared.context;
  const rawFormContext = prepared.formContext;
  if (
    prepared.status !== "ready" ||
    typeof text !== "string" ||
    typeof sourceLang !== "string" ||
    typeof targetLang !== "string" ||
    typeof interfaceLang !== "string" ||
    typeof sourceHash !== "string"
  ) {
    return json({ error: "translation_unavailable" }, 500);
  }
  const context: TranslationContextMessage[] = Array.isArray(rawContext)
    ? rawContext.flatMap((entry) => {
      if (typeof entry !== "object" || entry === null) return [];
      const speaker = (entry as Record<string, unknown>).speaker;
      const contextText = (entry as Record<string, unknown>).text;
      return (speaker === "viewer" || speaker === "partner") &&
          typeof contextText === "string" && contextText.trim().length > 0
        ? [{ speaker, text: contextText }]
        : [];
    })
    : [];
  const formContext = formContextFrom(rawFormContext);
  const providerKeys = providerCredentials({
    openRouterKey: OPEN_ROUTER_KEY,
    openAiKey: OPENAI_API_KEY,
    openRouterModel: OPENROUTER_MODEL,
    openAiModel: OPENAI_MODEL,
    openRouterProviderPolicy: OPENROUTER_PROVIDER_POLICY,
    environment: BLAB_ENV,
  });
  if (providerKeys.length === 0) {
    console.error("translation provider key is missing");
    return json({ error: "translation_unavailable" }, 500);
  }

  let result: ReturnType<typeof parseProviderResult> = null;
  let providerFailure = "unknown";
  let lastFailedSourceLang: string | null = null;
  for (const credential of providerKeys) {
    for (let attempt = 0; attempt < 2; attempt++) {
      const interfaceName = LANG_NAMES[interfaceLang] ?? interfaceLang;
      const targetName = LANG_NAMES[targetLang] ?? targetLang;
      const wrongModeGuidance = lastFailedSourceLang !== null &&
          lastFailedSourceLang !== targetLang
        ? ` Your previous response detected sourceLang=${lastFailedSourceLang}, which is not ${targetLang}, so mode=none/correction was invalid there — mode must be translation, and "translation" must be a genuine full-sentence rendering in ${targetName}, not a copy of the input.`
        : "";
      const retryGuidance = attempt === 0
        ? ""
        : `\n\nThe previous response was unusable. Re-check every contract rule. mode=none or mode=correction is valid only when sourceLang exactly equals ${targetLang}; for every other sourceLang, including other, mode must be translation. Infer the intended language of recognizable misspelled or expressively stretched text; repeated letters and playful capitalization do not make a supported message sourceLang=other. Treat likely names as names and transliterate them when the target script differs. When mode=translation, "translation" must be the complete sentence actually translated into ${targetName}; it must never be left as a copy of the original input, even for short, simple, or already-familiar-looking text. The tokens array is required whenever the translation contains words: reproduce the translation exactly with one content token per word, give every content token a short ${interfaceName} gloss, and include Latin-script romanization for every non-Latin content token. interfaceText must be the complete message in ${interfaceName} (${interfaceLang}); when the learning and interface languages differ, do not copy translation into interfaceText unless the wording is genuinely identical in both languages. Do not silently choose a gendered form when formAlternatives is required; return the explicit linked alternatives.${wrongModeGuidance}`;
      let llm: Response;
      try {
        llm = await fetchChatCompletion(credential, {
          temperature: attempt === 0 ? 0 : 0.4,
          max_completion_tokens: 12000,
          response_format: TRANSLATION_RESPONSE_FORMAT,
          messages: providerMessages({
            sourceLang,
            targetLang,
            interfaceLang,
            text,
            context,
            formContext,
            retryGuidance,
          }),
        });
      } catch {
        providerFailure = `${credential.provider}_unreachable`;
        console.error("translation provider attempt failed", {
          provider: credential.provider,
          model: credential.model,
          reason: providerFailure,
        });
        continue;
      }
      if (!llm.ok) {
        providerFailure = `${credential.provider}_http_${llm.status}`;
        console.error("translation provider attempt failed", {
          provider: credential.provider,
          model: credential.model,
          reason: providerFailure,
        });
        continue;
      }

      let payload: unknown;
      try {
        payload = await llm.json();
      } catch {
        providerFailure = `${credential.provider}_invalid_json`;
        console.error("translation provider attempt failed", {
          provider: credential.provider,
          model: credential.model,
          reason: providerFailure,
        });
        continue;
      }
      const content = (payload as {
        choices?: Array<{ message?: { content?: unknown } }>;
      })?.choices?.[0]?.message?.content;
      if (typeof content !== "string") {
        providerFailure = `${credential.provider}_missing_content`;
        console.error("translation provider attempt failed", {
          provider: credential.provider,
          model: credential.model,
          reason: providerFailure,
        });
        continue;
      }
      let candidate = parseProviderResult(
        content,
        text,
        targetLang,
        interfaceLang,
      );
      if (candidate === null) {
        providerFailure = `${credential.provider}_${
          providerResultFailureReason(content)
        }`;
        console.error("translation provider attempt failed", {
          provider: credential.provider,
          model: credential.model,
          reason: providerFailure,
        });
        continue;
      }
      if (
        genderedAmbiguityNeedsRetry(candidate, sourceLang, targetLang, text)
      ) {
        providerFailure = `${credential.provider}_gendered_ambiguity`;
        console.error("translation provider attempt failed", {
          provider: credential.provider,
          model: credential.model,
          reason: providerFailure,
        });
        continue;
      }
      if (correctionNeedsRetry(candidate, text)) {
        providerFailure = `${credential.provider}_incomplete_correction`;
        console.error("translation provider attempt failed", {
          provider: credential.provider,
          model: credential.model,
          reason: providerFailure,
        });
        continue;
      }
      const needsFormAudit = formContext !== undefined &&
        missingFormAlternativesNeedsAudit(
          candidate,
          targetLang,
          formContext,
          attempt,
        );
      if (needsFormAudit) {
        const audit = await auditGrammaticalForm(
          credential,
          text,
          candidate.translation,
          candidate.sourceLang,
          targetLang,
          interfaceLang,
          formContext!,
        );
        if (audit === null) {
          providerFailure = `${credential.provider}_form_audit_unavailable`;
          break;
        }
        if (audit.requiresChoice) {
          const auditedCandidate = applyConfirmedFormAudit(
            candidate,
            audit,
            formContext!,
          );
          if (auditedCandidate === null) {
            providerFailure = `${credential.provider}_invalid_form_audit`;
            continue;
          }
          candidate = auditedCandidate;
        } else {
          candidate.formAlternatives = null;
        }
      }
      if (candidate.formAlternatives && formContext) {
        candidate.formAlternatives = normalizeFormSubject(
          candidate.formAlternatives,
          formContext,
          text,
          candidate.sourceLang,
        );
      }
      if (translationNeedsRetry(candidate, targetLang, text)) {
        lastFailedSourceLang = candidate.sourceLang;
        providerFailure = `${credential.provider}_untranslated`;
        console.error("translation provider attempt failed", {
          provider: credential.provider,
          model: credential.model,
          reason: providerFailure,
        });
        continue;
      }
      if (interfaceOutputNeedsRetry(candidate, targetLang, interfaceLang)) {
        const repaired = await repairInterfaceText(
          credential,
          candidate.translation,
          targetLang,
          interfaceLang,
        );
        if (repaired !== null) {
          candidate.interfaceText = repaired;
          result = candidate;
          break;
        }
        providerFailure = `${credential.provider}_interface_repair`;
        console.error("translation provider attempt failed", {
          provider: credential.provider,
          model: credential.model,
          reason: providerFailure,
        });
        continue;
      }
      console.log(
        `translation provider succeeded via ${providerName(credential)}`,
      );
      result = candidate;
      break;
    }
    if (result !== null) break;
  }
  if (result === null) {
    console.error("translation provider failed after retry", {
      reason: providerFailure,
    });
    return json({
      error: "translation_unavailable",
      reason: providerFailure,
    }, 502);
  }

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const completion = isWorker
    ? await admin.rpc("complete_message_translation_job", {
      p_job_id: internalJobId,
      p_translation_text: result.translation,
      p_interface_text: result.interfaceText,
      p_source_lang: result.sourceLang,
      p_aid_mode: result.mode,
      p_explanation: result.explanation,
      p_confidence: result.confidence,
      p_tokens: result.tokens,
      p_form_alternatives: result.formAlternatives,
      p_cache_contract_version: CACHE_CONTRACT_VERSION,
    })
    : await admin.rpc("complete_message_translation", {
      p_message_id: messageId,
      p_requester_id: requesterId,
      p_target_lang: targetLang,
      p_interface_lang: interfaceLang,
      p_source_hash: sourceHash,
      p_translation_text: result.translation,
      p_interface_text: result.interfaceText,
      p_source_lang: result.sourceLang,
      p_aid_mode: result.mode,
      p_explanation: result.explanation,
      p_confidence: result.confidence,
      p_tokens: result.tokens,
      p_form_alternatives: result.formAlternatives,
      p_cache_contract_version: CACHE_CONTRACT_VERSION,
    });
  const { data: completed, error: completionError } = completion;
  if (completionError) {
    console.error("translation cache completion failed");
    return json({ error: "translation_unavailable" }, 500);
  }
  if (completed !== true) {
    return json({ error: "translation_stale" }, 409);
  }
  return json({ ...result, interfaceLang });
});
