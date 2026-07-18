// Server-authoritative real-chat translator. The client supplies only a
// message ID. Postgres validates the caller and derives source text and target
// language before quota-limited provider work begins.
//
// Deploy: supabase functions deploy translate-message
// OPEN_ROUTER_KEY remains server-side.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  OPENROUTER_PROVIDER,
  parseProviderResult,
  systemPrompt,
  validateRequest,
} from "./contract.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const OPEN_ROUTER_KEY = Deno.env.get("OPEN_ROUTER_KEY");
const MODEL = "openai/gpt-4o-mini";

function json(
  body: unknown,
  status = 200,
  headers: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...headers },
  });
}

Deno.serve(async (req) => {
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
  if (preparedError || typeof preparedData !== "object" || preparedData === null) {
    console.error("translation prepare failed");
    return json({ error: "translation_unavailable" }, 500);
  }
  const prepared = preparedData as Record<string, unknown>;
  if (prepared.status === "cached") {
    return json({
      translation: prepared.translation,
      english: prepared.english,
      sourceLang: prepared.sourceLang,
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
  const sourceHash = prepared.sourceHash;
  if (
    prepared.status !== "ready" ||
    typeof text !== "string" ||
    typeof sourceLang !== "string" ||
    typeof targetLang !== "string" ||
    typeof sourceHash !== "string"
  ) {
    return json({ error: "translation_unavailable" }, 500);
  }
  if (!OPEN_ROUTER_KEY) {
    console.error("translation provider key is missing");
    return json({ error: "translation_unavailable" }, 500);
  }

  let llm: Response;
  try {
    llm = await fetch("https://openrouter.ai/api/v1/chat/completions", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${OPEN_ROUTER_KEY}`,
      },
      body: JSON.stringify({
        model: MODEL,
        max_completion_tokens: 12000,
        response_format: { type: "json_object" },
        provider: OPENROUTER_PROVIDER,
        messages: [
          { role: "system", content: systemPrompt(sourceLang, targetLang) },
          { role: "user", content: text },
        ],
      }),
    });
  } catch {
    console.error("translation provider unreachable");
    return json({ error: "translation_unavailable" }, 502);
  }
  if (!llm.ok) {
    console.error("translation provider rejected request", { status: llm.status });
    return json({ error: "translation_unavailable" }, 502);
  }

  let payload: unknown;
  try {
    payload = await llm.json();
  } catch {
    return json({ error: "translation_unavailable" }, 502);
  }
  const content = (payload as {
    choices?: Array<{ message?: { content?: unknown } }>;
  })?.choices?.[0]?.message?.content;
  if (typeof content !== "string") {
    return json({ error: "translation_unavailable" }, 502);
  }
  const result = parseProviderResult(content, text, targetLang);
  if (result === null) {
    return json({ error: "translation_unavailable" }, 502);
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
      p_source_hash: sourceHash,
      p_translation_text: result.translation,
      p_english_text: result.english,
      p_source_lang: result.sourceLang,
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
  return json(result);
});
