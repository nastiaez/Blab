// Portfolio mode live English → Tamil translator.
//
// Calls OpenRouter (OpenAI-compatible chat completions) routed to
// Anthropic Claude Haiku 4.5 with a fixed prompt that returns
// `{ translation, tokens[] }` JSON matching the curated portfolio chat
// shape. No authn — portfolio mode is a public demo. Basic guards:
//   - POST only
//   - 400-char hard cap on `text`
//   - target must equal "ta"
//
// Deploy:  supabase functions deploy translate-portfolio --no-verify-jwt
// Required env (set via `supabase secrets set`):
//   OPEN_ROUTER_KEY

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const OPEN_ROUTER_KEY = Deno.env.get("OPEN_ROUTER_KEY")!;
const MODEL = "minimax/minimax-m3";
const MAX_CHARS = 400;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

const SYSTEM_PROMPT = `You translate English sentences into Tamil for a
language-learning app. You ALWAYS reply with strict JSON in this exact
shape and nothing else (no prose, no markdown fences):

{
  "translation": "<full Tamil translation as one string>",
  "tokens": [
    { "text": "<segment>", "english": "<1-3 word gloss>", "roman": "<IAST-style romanization>", "isContent": true },
    { "text": " ", "isContent": false }
  ]
}

Rules:
- The "tokens" array, when each token's "text" is concatenated in order,
  MUST exactly reproduce the "translation" string (whitespace and
  punctuation included).
- Content tokens (Tamil words) have isContent=true and include "english"
  + "roman". Whitespace, punctuation, and emoji are separate tokens with
  isContent=false and MUST NOT include "english" or "roman".
- Use IAST-style transliteration for "roman" (e.g. "Vaṇakkam", "Eppadi").
- Translation must read naturally to a Tamil speaker — colloquial, not
  word-for-word.`;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  let body: { text?: unknown; target?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const text = body.text;
  const target = body.target;
  if (typeof text !== "string" || text.trim().length === 0) {
    return json({ error: "missing_text" }, 400);
  }
  if (text.length > MAX_CHARS) {
    return json({ error: "text_too_long" }, 400);
  }
  if (target !== "ta") {
    return json({ error: "unsupported_target" }, 400);
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
        max_tokens: 2048,
        response_format: { type: "json_object" },
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: text.trim() },
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
  // Extract the JSON object from the model's reply. Strip markdown fences
  // and any prose around the object. Some models (e.g. minimax-m3) emit
  // a JSON object followed by trailing chatter; we slice from the first
  // `{` to the LAST matching `}` and parse that.
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
    !Array.isArray((parsed as { tokens?: unknown }).tokens)
  ) {
    return json({ error: "upstream_malformed" }, 502);
  }
  return json(parsed);
});
