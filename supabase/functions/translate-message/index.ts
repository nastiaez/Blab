// Server-authoritative real-chat translator. The client supplies only a
// message ID. Postgres validates the caller and derives source text and target
// language before quota-limited provider work begins.
//
// Deploy: supabase functions deploy translate-message
// OPEN_ROUTER_KEY remains server-side.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  genderedAmbiguityNeedsRetry,
  INTERFACE_RESPONSE_FORMAT,
  interfaceOutputNeedsRetry,
  interfaceRepairSystemPrompt,
  LANG_NAMES,
  OPENROUTER_PROVIDER,
  parseProviderResult,
  type ProviderCredential,
  providerCredentials,
  providerMessages,
  providerResultFailureReason,
  TRANSLATION_RESPONSE_FORMAT,
  type TranslationContextMessage,
  validateRequest,
} from "./contract.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BLAB_ENV = Deno.env.get("BLAB_ENV");
const OPEN_ROUTER_KEY = Deno.env.get("OPEN_ROUTER_KEY");
const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const OPENROUTER_MODEL = Deno.env.get("OPENROUTER_MODEL");
const OPENAI_MODEL = Deno.env.get("OPENAI_MODEL");
const OPENROUTER_PROVIDER_POLICY = Deno.env.get("OPENROUTER_PROVIDER_POLICY");
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

  let body: { messageId?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const validation = validateRequest(body);
  if ("error" in validation) return json({ error: validation.error }, 400);
  const { messageId } = validation.request;

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await userClient.auth.getUser();
  if (userError || !userData.user) {
    return json({ error: "authentication_required" }, 401);
  }

  const { data: preparedData, error: preparedError } = await userClient.rpc(
    "request_message_translation",
    { p_message_id: messageId },
  );
  if (
    preparedError || typeof preparedData !== "object" || preparedData === null
  ) {
    console.error("translation prepare failed");
    return json({ error: "translation_unavailable" }, 500);
  }
  const prepared = preparedData as Record<string, unknown>;
  if (prepared.status === "cached") {
    return json({
      translation: prepared.translation,
      interfaceText: prepared.interfaceText,
      mode: prepared.mode,
      sourceLang: prepared.sourceLang,
      interfaceLang: prepared.interfaceLang,
      explanation: prepared.explanation,
      confidence: prepared.confidence,
      tokens: prepared.tokens,
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
  if (prepared.status === "forbidden" || prepared.status === "not_eligible") {
    return json({ error: "translation_not_allowed" }, 403);
  }

  const text = prepared.text;
  const sourceLang = prepared.sourceLang;
  const targetLang = prepared.targetLang;
  const interfaceLang = prepared.interfaceLang;
  const sourceHash = prepared.sourceHash;
  const rawContext = prepared.context;
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
  for (const credential of providerKeys) {
    for (let attempt = 0; attempt < 2; attempt++) {
      const interfaceName = LANG_NAMES[interfaceLang] ?? interfaceLang;
      const retryGuidance = attempt === 0
        ? ""
        : `\n\nThe previous response was unusable. Re-check every contract rule. mode=none or mode=correction is valid only when sourceLang exactly equals ${targetLang}; for every other sourceLang, including other, mode must be translation. Infer the intended language of recognizable misspelled text. interfaceText must be the complete message in ${interfaceName} (${interfaceLang}); when the learning and interface languages differ, do not copy translation into interfaceText unless the wording is genuinely identical in both languages. For Ukrainian, do not use parenthetical or slash gender alternatives such as "був(ла)", "радий(а)", "був/була", or "радий/рада"; rewrite with impersonal neutral wording instead.`;
      let llm: Response;
      try {
        llm = await fetchChatCompletion(credential, {
          temperature: 0,
          max_completion_tokens: 12000,
          response_format: TRANSLATION_RESPONSE_FORMAT,
          messages: providerMessages({
            sourceLang,
            targetLang,
            interfaceLang,
            text,
            context,
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
      const candidate = parseProviderResult(
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
  const { data: completed, error: completionError } = await admin.rpc(
    "complete_message_translation",
    {
      p_message_id: messageId,
      p_requester_id: userData.user.id,
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
    },
  );
  if (completionError) {
    console.error("translation cache completion failed");
    return json({ error: "translation_unavailable" }, 500);
  }
  if (completed !== true) {
    return json({ error: "translation_stale" }, 409);
  }
  return json({ ...result, interfaceLang });
});
