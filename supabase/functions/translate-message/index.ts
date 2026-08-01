// Server-authoritative real-chat translator. The client supplies only a
// message ID. Postgres validates the caller and derives source text and target
// language before quota-limited provider work begins.
//
// Deploy: supabase functions deploy translate-message
// OPEN_ROUTER_KEY remains server-side.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  fetchProviderWithTimeout,
  INTERFACE_RESPONSE_FORMAT,
  interfaceOutputNeedsRetry,
  LANG_NAMES,
  OPENROUTER_PROVIDER,
  parseProviderResult,
  providerCallFailureReason,
  providerResultFailureReason,
  shortInputRetryGuidance,
  systemPrompt,
  TRANSLATION_RESPONSE_FORMAT,
  translationOutputNeedsRetry,
  validateRequest,
} from "./contract.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const OPEN_ROUTER_KEY = Deno.env.get("OPEN_ROUTER_KEY");
const MODEL = "openai/gpt-4o-mini";
const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

async function repairInterfaceText(
  learningText: string,
  targetLang: string,
  interfaceLang: string,
): Promise<string | null> {
  const targetName = LANG_NAMES[targetLang] ?? targetLang;
  const interfaceName = LANG_NAMES[interfaceLang] ?? interfaceLang;
  let response: Awaited<ReturnType<typeof fetchProviderWithTimeout>>;
  try {
    response = await fetchProviderWithTimeout(
      "https://openrouter.ai/api/v1/chat/completions",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${OPEN_ROUTER_KEY}`,
        },
        body: JSON.stringify({
          model: MODEL,
          temperature: 0,
          max_completion_tokens: 4000,
          response_format: INTERFACE_RESPONSE_FORMAT,
          provider: OPENROUTER_PROVIDER,
          messages: [
            {
              role: "system",
              content:
                `Translate the complete user message from ${targetName} (${targetLang}) into ${interfaceName} (${interfaceLang}). Preserve meaning, tone, names, URLs, emoji, and punctuation. Translate all translatable words even when the message is short. Return strict JSON only: {"interfaceText":"<complete ${interfaceName} translation>"}`,
            },
            { role: "user", content: learningText },
          ],
        }),
      },
    );
  } catch {
    return null;
  }
  if (!response.ok) return null;

  let payload: unknown;
  try {
    payload = JSON.parse(response.body);
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
  if (!OPEN_ROUTER_KEY) {
    console.error("translation provider key is missing");
    return json({ error: "translation_unavailable" }, 500);
  }

  let result: ReturnType<typeof parseProviderResult> = null;
  let providerFailure = "unknown";
  let echoedShortInput = false;
  for (let attempt = 0; attempt < 2; attempt++) {
    const interfaceName = LANG_NAMES[interfaceLang] ?? interfaceLang;
    const retryGuidance = attempt === 0
      ? ""
      : echoedShortInput
      ? shortInputRetryGuidance(targetLang)
      : `\n\nThe previous response was unusable. Re-check every contract rule. mode=none or mode=correction is valid only when sourceLang exactly equals ${targetLang}; for every other sourceLang, including other, mode must be translation. Infer the intended language of recognizable misspelled text. interfaceText must be the complete message in ${interfaceName} (${interfaceLang}); when the learning and interface languages differ, do not copy translation into interfaceText unless the wording is genuinely identical in both languages.`;
    let llm: Awaited<ReturnType<typeof fetchProviderWithTimeout>>;
    try {
      llm = await fetchProviderWithTimeout(
        "https://openrouter.ai/api/v1/chat/completions",
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${OPEN_ROUTER_KEY}`,
          },
          body: JSON.stringify({
            model: MODEL,
            temperature: 0,
            max_completion_tokens: 12000,
            response_format: TRANSLATION_RESPONSE_FORMAT,
            provider: OPENROUTER_PROVIDER,
            messages: [
              {
                role: "system",
                content: systemPrompt(sourceLang, targetLang, interfaceLang) +
                  retryGuidance,
              },
              { role: "user", content: text },
            ],
          }),
        },
      );
    } catch (error) {
      providerFailure = providerCallFailureReason(error);
      continue;
    }
    if (!llm.ok) {
      providerFailure = `http_${llm.status}`;
      continue;
    }

    let payload: unknown;
    try {
      payload = JSON.parse(llm.body);
    } catch {
      providerFailure = "invalid_json";
      continue;
    }
    const content = (payload as {
      choices?: Array<{ message?: { content?: unknown } }>;
    })?.choices?.[0]?.message?.content;
    if (typeof content !== "string") {
      providerFailure = "missing_content";
      continue;
    }
    const candidate = parseProviderResult(
      content,
      text,
      targetLang,
      interfaceLang,
    );
    if (candidate === null) {
      providerFailure = providerResultFailureReason(content);
      continue;
    }
    // Checked before the interface repair below, which would otherwise accept
    // an echoed learning line by "repairing" it back into the same wording.
    if (
      attempt === 0 && translationOutputNeedsRetry(candidate, text, targetLang)
    ) {
      echoedShortInput = true;
      providerFailure = "untranslated_short_input";
      continue;
    }
    if (interfaceOutputNeedsRetry(candidate, targetLang, interfaceLang)) {
      const repaired = await repairInterfaceText(
        candidate.translation,
        targetLang,
        interfaceLang,
      );
      if (repaired !== null) {
        candidate.interfaceText = repaired;
        result = candidate;
        break;
      }
      providerFailure = "interface_repair";
      continue;
    }
    result = candidate;
    break;
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
  // collapsedRewrite is a server-side retry signal, not part of the contract.
  const { collapsedRewrite: _collapsedRewrite, ...response } = result;
  return json({ ...response, interfaceLang });
});
