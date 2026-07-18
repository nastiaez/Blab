export const MAX_CHARS = 2000;

export const OPENROUTER_PROVIDER = {
  only: ["azure"],
  allow_fallbacks: true,
  require_parameters: true,
  data_collection: "deny",
  zdr: true,
} as const;

export const LANG_NAMES: Record<string, string> = {
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

const NON_LATIN = new Set(["ta", "uk", "hi"]);

export type TranslationRequest = {
  messageId: string;
};

export type TranslationRequestValidation =
  | { request: TranslationRequest }
  | { error: string };

export function characterCount(text: string): number {
  const segmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" });
  return Array.from(segmenter.segment(text)).length;
}

export function validateRequest(body: { messageId?: unknown }): TranslationRequestValidation {
  const messageId = body.messageId;
  if (
    typeof messageId !== "string" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(messageId)
  ) {
    return { error: "invalid_message_id" };
  }
  return { request: { messageId } };
}

export type TranslationResult = {
  sourceLang: string;
  translation: string;
  english: string;
  tokens: unknown[];
};

export function parseProviderResult(
  content: string,
  text: string,
  targetLang: string,
): TranslationResult | null {
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
    return null;
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
    return null;
  }

  const result = parsed as TranslationResult;
  if (result.sourceLang === "en") result.english = text;
  if (result.sourceLang === targetLang) result.translation = text;
  if (targetLang === "en") result.english = result.translation;
  if (result.translation.trim().length === 0 || result.english.trim().length === 0) {
    return null;
  }

  let reproduced = "";
  for (const token of result.tokens) {
    if (
      typeof token !== "object" ||
      token === null ||
      typeof (token as { text?: unknown }).text !== "string" ||
      typeof (token as { isContent?: unknown }).isContent !== "boolean"
    ) {
      return null;
    }
    reproduced += (token as { text: string }).text;
  }
  return reproduced === result.translation ? result : null;
}

export function systemPrompt(sourceLang: string, targetLang: string): string {
  const targetName = LANG_NAMES[targetLang];
  const sourceInstruction = sourceLang === "auto"
    ? `Detect the input language. It should be one of: ${
      Object.entries(LANG_NAMES).map(([code, name]) => `${code}=${name}`).join(", ")
    }.`
    : `The input language is ${LANG_NAMES[sourceLang]} (${sourceLang}).`;
  const romanGuidance = NON_LATIN.has(targetLang)
    ? `For each content token include "roman", a Latin-script romanization.`
    : `"roman" may be omitted when the target token already uses Latin script.`;

  return `You normalize a message for a language-learning chat.

${sourceInstruction}
The viewer's learning language is ${targetName} (${targetLang}).

Return strict JSON only:
{
  "sourceLang": "<detected supported language code>",
  "translation": "<full message in ${targetName}>",
  "english": "<full message in English>",
  "tokens": [
    { "text": "<segment of translation>", "english": "<1-3 word English gloss>", "roman": "<romanization>", "isContent": true },
    { "text": " ", "isContent": false }
  ]
}

Rules:
- Preserve meaning, tone, names, URLs, emoji, and punctuation.
- Translate the entire input. Never summarize, omit, deduplicate, or combine repeated content.
- "translation" is always in ${targetName}. If the input is already ${targetName}, preserve the trimmed input exactly.
- "english" is always in English. If the input is already English, preserve the trimmed input exactly.
- When targetLang is en, "translation" and "english" must be identical.
- sourceLang must be one of the supported codes listed above.
- Concatenating every tokens[].text must exactly reproduce "translation".
- Content tokens are segments of "translation" and include a short English gloss.
- Whitespace, punctuation, and emoji use isContent=false and omit glosses.
- ${romanGuidance}`;
}
