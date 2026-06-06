// Real-chat translator. Calls OpenRouter (OpenAI-compatible) with a
// parametrized prompt that returns { translation, tokens[] } JSON
// matching the curated chat shape. Model is whatever MODEL is set to
// below (currently openai/gpt-4o-mini — Anthropic Haiku ran here
// previously and remains a swap-in option).
// Auth required (Supabase JWT). Basic guards:
//   - POST only
//   - 400-char hard cap on `text`
//   - sourceLang + targetLang required, must be supported codes
//
// Deploy:  supabase functions deploy translate-message
// Reuses ANTHROPIC_API_KEY / OPEN_ROUTER_KEY secret already set on the
// project for translate-portfolio.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const OPEN_ROUTER_KEY = Deno.env.get("OPEN_ROUTER_KEY")!;
const MODEL = "openai/gpt-4o-mini";
const MAX_CHARS = 400;

const LANG_NAMES: Record<string, string> = {
  en: "English",
  ta: "Tamil",
  uk: "Ukrainian",
  es: "Spanish",
  de: "German",
  fr: "French",
  it: "Italian",
  pt: "Portuguese",
  nl: "Dutch",
  tr: "Turkish",
  hi: "Hindi",
};

const NON_LATIN: Set<string> = new Set(["ta", "uk", "hi"]);

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function systemPrompt(sourceLang: string, targetLang: string): string {
  const sourceName = LANG_NAMES[sourceLang];
  const targetName = LANG_NAMES[targetLang];
  const romanGuidance = NON_LATIN.has(targetLang)
    ? `- For each content token (a ${targetName} word) include "roman" (Latin-script romanization, e.g. IAST for Tamil — "Vaṇakkam", "Eppadi").`
    : `- "roman" may be omitted on content tokens when ${targetName} is already in Latin script.`;

  return `You translate ${sourceName} sentences into ${targetName} for a
language-learning app.

DIRECTION: source = ${sourceName}, target = ${targetName}.
The user sends a ${sourceName} sentence. You MUST return a ${targetName}
translation. The "translation" field must be in ${targetName}, never
${sourceName}.

You ALWAYS reply with strict JSON in this exact shape and nothing else
(no prose, no markdown fences):

{
  "translation": "<full ${targetName} translation as one string>",
  "tokens": [
    { "text": "<segment of the ${targetName} TRANSLATION>", "english": "<1-3 word ${sourceName} gloss of this ${targetName} segment>", "roman": "<Latin-script romanization of the ${targetName} segment>", "isContent": true },
    { "text": " ", "isContent": false }
  ]
}

Rules:
- The "translation" top-level field is the full natural ${targetName}
  sentence — colloquial, not word-for-word. Always in ${targetName}.
- The "tokens" array's "text" fields, concatenated in order, MUST exactly
  reproduce the "translation" string (whitespace and punctuation
  included). Tokens are segments of the ${targetName} TRANSLATION, NOT
  of the ${sourceName} input.
- Content tokens (${targetName} words) have isContent=true and include
  "english" (the ${sourceName} meaning of this ${targetName} word — 1-3
  words) and "roman".
- Whitespace, punctuation, and emoji are separate tokens with
  isContent=false and MUST NOT include "english" or "roman".
${romanGuidance}

EXAMPLE — source=English, target=Tamil, input "morning! how are you?":
{
  "translation": "காலை வணக்கம், எப்படி இருக்கீங்க?",
  "tokens": [
    { "text": "காலை", "english": "morning", "roman": "kaalai", "isContent": true },
    { "text": " ", "isContent": false },
    { "text": "வணக்கம்", "english": "greeting", "roman": "vanakkam", "isContent": true },
    { "text": ",", "isContent": false },
    { "text": " ", "isContent": false },
    { "text": "எப்படி", "english": "how", "roman": "eppadi", "isContent": true },
    { "text": " ", "isContent": false },
    { "text": "இருக்கீங்க", "english": "are you", "roman": "irukkeenga", "isContent": true },
    { "text": "?", "isContent": false }
  ]
}`;
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
  const text = body.text;
  const sourceLang = body.sourceLang;
  const targetLang = body.targetLang;
  if (typeof text !== "string" || text.trim().length === 0) {
    return json({ error: "missing_text" }, 400);
  }
  if (text.length > MAX_CHARS) {
    return json({ error: "text_too_long" }, 400);
  }
  if (typeof sourceLang !== "string" || !(sourceLang in LANG_NAMES)) {
    return json({ error: "unsupported_source" }, 400);
  }
  if (typeof targetLang !== "string" || !(targetLang in LANG_NAMES)) {
    return json({ error: "unsupported_target" }, 400);
  }
  if (sourceLang === targetLang) {
    return json({ error: "same_language" }, 400);
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
          { role: "system", content: systemPrompt(sourceLang, targetLang) },
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
