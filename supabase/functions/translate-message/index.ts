// Real-chat translator. Calls OpenRouter (OpenAI-compatible) with a
// parametrized prompt that detects the authored language and returns a
// normalized target-language main text plus English subtitle and tokens.
// Model is whatever MODEL is set to
// below (currently openai/gpt-4o-mini — Anthropic Haiku ran here
// previously and remains a swap-in option).
// Auth required (Supabase JWT). Basic guards:
//   - POST only
//   - 2,000-character hard cap on `text`
//   - sourceLang is `auto` or a supported legacy hint
//   - targetLang is a supported code
//
// Deploy:  supabase functions deploy translate-message
// Reuses ANTHROPIC_API_KEY / OPEN_ROUTER_KEY secret already set on the
// project for translate-portfolio.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import {
  LANG_NAMES,
  systemPrompt,
  validateRequest,
} from "./contract.ts";

const OPEN_ROUTER_KEY = Deno.env.get("OPEN_ROUTER_KEY")!;
const MODEL = "openai/gpt-4o-mini";

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  let body: { text?: unknown; sourceLang?: unknown; targetLang?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const validation = validateRequest(body);
  if ("error" in validation) return json({ error: validation.error }, 400);
  const { text, sourceLang, targetLang } = validation.request;

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
        max_tokens: 12000,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: systemPrompt(sourceLang, targetLang) },
          { role: "user", content: text },
        ],
      }),
    });
  } catch (e) {
    return json({ error: `upstream_unreachable: ${e}` }, 502);
  }
  if (!llm.ok) {
    const detail = await llm.text();
    return json({ error: "upstream_error", status: llm.status, detail }, 502);
  }
  const payload = await llm.json();
  const content = payload?.choices?.[0]?.message?.content;
  if (typeof content !== "string") {
    return json({ error: "upstream_unexpected_shape" }, 502);
  }
  let cleaned = content
    .trim()
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();
  const firstBrace = cleaned.indexOf("{");
  const lastBrace = cleaned.lastIndexOf("}");
  if (firstBrace >= 0 && lastBrace > firstBrace) {
    cleaned = cleaned.slice(firstBrace, lastBrace + 1);
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(cleaned);
  } catch {
    return json({ error: "upstream_non_json", raw: content.slice(0, 800) }, 502);
  }
  if (
    typeof parsed !== "object" ||
    parsed === null ||
    typeof (parsed as { translation?: unknown }).translation !== "string" ||
    typeof (parsed as { english?: unknown }).english !== "string" ||
    typeof (parsed as { sourceLang?: unknown }).sourceLang !== "string" ||
    !((parsed as { sourceLang: string }).sourceLang in LANG_NAMES) ||
    !Array.isArray((parsed as { tokens?: unknown }).tokens)
  ) {
    return json({ error: "upstream_malformed" }, 502);
  }
  const result = parsed as {
    sourceLang: string;
    translation: string;
    english: string;
    tokens: unknown[];
  };
  if (result.sourceLang === "en") result.english = text;
  if (result.sourceLang === targetLang) result.translation = text;
  if (targetLang === "en") result.english = result.translation;
  return json(result);
});
