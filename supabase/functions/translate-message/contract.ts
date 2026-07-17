export const MAX_CHARS = 2000;

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
  text: string;
  sourceLang: string;
  targetLang: string;
};

export type TranslationRequestValidation =
  | { request: TranslationRequest }
  | { error: string };

export function characterCount(text: string): number {
  const segmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" });
  return Array.from(segmenter.segment(text)).length;
}

export function validateRequest(body: {
  text?: unknown;
  sourceLang?: unknown;
  targetLang?: unknown;
}): TranslationRequestValidation {
  const text = body.text;
  const sourceLang = body.sourceLang;
  const targetLang = body.targetLang;
  if (typeof text !== "string" || text.trim().length === 0) {
    return { error: "missing_text" };
  }
  if (characterCount(text.trim()) > MAX_CHARS) {
    return { error: "text_too_long" };
  }
  if (
    typeof sourceLang !== "string" ||
    (sourceLang !== "auto" && !(sourceLang in LANG_NAMES))
  ) {
    return { error: "unsupported_source" };
  }
  if (typeof targetLang !== "string" || !(targetLang in LANG_NAMES)) {
    return { error: "unsupported_target" };
  }
  if (sourceLang === targetLang) {
    return { error: "same_language" };
  }
  return {
    request: { text: text.trim(), sourceLang, targetLang },
  };
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
