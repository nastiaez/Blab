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
export const INTERFACE_LANGS = new Set(["en", "uk", "de", "es"]);
export const OTHER_SOURCE_LANG = "other";
export const LEARNING_AID_MODES = new Set([
  "translation",
  "correction",
  "none",
]);
export const CORRECTION_CONFIDENCE = new Set(["low", "medium", "high"]);

export type LearningAidMode = "translation" | "correction" | "none";
export type CorrectionConfidence = "low" | "medium" | "high";

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

export function validateRequest(
  body: { messageId?: unknown },
): TranslationRequestValidation {
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
  mode: LearningAidMode;
  sourceLang: string;
  translation: string;
  interfaceText: string;
  explanation: string | null;
  confidence: CorrectionConfidence | null;
  tokens: unknown[];
};

/// A copied learning line is usually a provider mistake when the viewer's
/// interface uses another language. It is only a retry signal, not a hard
/// validation failure, because names and language-neutral text can legitimately
/// be identical in both languages.
export function interfaceOutputNeedsRetry(
  result: TranslationResult,
  targetLang: string,
  interfaceLang: string,
): boolean {
  return targetLang !== interfaceLang &&
    result.interfaceText.trim().toLocaleLowerCase() ===
      result.translation.trim().toLocaleLowerCase() &&
    /\p{L}/u.test(result.translation);
}

export function parseProviderResult(
  content: string,
  text: string,
  targetLang: string,
  interfaceLang: string,
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
    typeof (parsed as { mode?: unknown }).mode !== "string" ||
    !LEARNING_AID_MODES.has((parsed as { mode: string }).mode) ||
    typeof (parsed as { translation?: unknown }).translation !== "string" ||
    typeof (parsed as { interfaceText?: unknown }).interfaceText !== "string" ||
    typeof (parsed as { sourceLang?: unknown }).sourceLang !== "string" ||
    !(
      (parsed as { sourceLang: string }).sourceLang in LANG_NAMES ||
      (parsed as { sourceLang: string }).sourceLang === OTHER_SOURCE_LANG
    ) ||
    !Array.isArray((parsed as { tokens?: unknown }).tokens)
  ) {
    return null;
  }

  const result = parsed as TranslationResult;
  const sourceMatchesTarget = result.sourceLang === targetLang;
  if (!sourceMatchesTarget && result.mode !== "translation") return null;
  if (sourceMatchesTarget && result.mode === "translation") return null;
  if (result.translation.trim().length === 0) {
    return null;
  }
  if (result.interfaceText.trim().length === 0) return null;
  // These display lines are fully determined by trusted inputs. Normalize
  // them instead of rejecting an otherwise valid provider translation when
  // the model rewrites a typo or returns two slightly different copies.
  if (interfaceLang === targetLang) {
    result.interfaceText = result.translation;
  } else if (result.sourceLang === interfaceLang) {
    result.interfaceText = text;
  }
  if (result.mode === "none") {
    if (
      result.translation !== text ||
      result.explanation !== null ||
      result.confidence !== null
    ) return null;
  } else if (result.mode === "correction") {
    if (
      result.translation === text ||
      typeof result.explanation !== "string" ||
      result.explanation.trim().length === 0 ||
      typeof result.confidence !== "string" ||
      !CORRECTION_CONFIDENCE.has(result.confidence)
    ) return null;
  } else {
    result.explanation = null;
    result.confidence = null;
  }

  let reproduced = "";
  let validTokens = true;
  for (const token of result.tokens) {
    if (
      typeof token !== "object" ||
      token === null ||
      typeof (token as { text?: unknown }).text !== "string" ||
      typeof (token as { isContent?: unknown }).isContent !== "boolean"
    ) {
      validTokens = false;
      break;
    }
    if (
      (token as { isContent: boolean }).isContent &&
      (
        typeof (token as { gloss?: unknown }).gloss !== "string" ||
        (token as { gloss: string }).gloss.trim().length === 0
      )
    ) {
      validTokens = false;
      break;
    }
    reproduced += (token as { text: string }).text;
  }
  if (!validTokens || reproduced !== result.translation) {
    // Token metadata powers optional word lookup. A malformed token list must
    // not hide an otherwise valid full-message translation.
    result.tokens = [];
  }
  return result;
}

export function systemPrompt(
  sourceLang: string,
  targetLang: string,
  interfaceLang: string,
): string {
  const targetName = LANG_NAMES[targetLang];
  const interfaceName = LANG_NAMES[interfaceLang];
  const sourceInstruction = sourceLang === "auto"
    ? `Detect the input language. Use its code when it is one of: ${
      Object.entries(LANG_NAMES).map(([code, name]) => `${code}=${name}`).join(
        ", ",
      )
    }. Infer the intended supported language when short text contains spelling or keyboard-adjacent typos. For ambiguous malformed text, use the viewer's ${interfaceName} (${interfaceLang}) interface language as a weak hint when its script and recognizable fragments fit; never override a clearly recognizable different language. Only use sourceLang=${OTHER_SOURCE_LANG} when no supported intended language can be inferred.`
    : `The input language is ${LANG_NAMES[sourceLang]} (${sourceLang}).`;
  const romanGuidance = NON_LATIN.has(targetLang)
    ? `For each content token include "roman", a Latin-script romanization.`
    : `"roman" may be omitted when the target token already uses Latin script.`;

  return `You normalize a message for a language-learning chat.

${sourceInstruction}
The viewer's learning language is ${targetName} (${targetLang}).
The viewer's interface language is ${interfaceName} (${interfaceLang}).

Return strict JSON only:
{
  "mode": "<translation, correction, or none>",
  "sourceLang": "<detected supported code, or ${OTHER_SOURCE_LANG}>",
  "translation": "<the complete ${targetName} learning-language line>",
  "interfaceText": "<the complete ${interfaceName} interface-language line>",
  "explanation": "<short ${interfaceName} correction explanation, or null>",
  "confidence": "<low, medium, high, or null>",
  "tokens": [
    { "text": "<segment of translation>", "gloss": "<1-3 word ${interfaceName} gloss>", "roman": "<romanization>", "isContent": true },
    { "text": " ", "isContent": false }
  ]
}

Rules:
- Preserve meaning, tone, names, URLs, emoji, and punctuation.
- First detect sourceLang, then choose exactly one mode.
- If sourceLang differs from ${targetLang}, including sourceLang=${OTHER_SOURCE_LANG}, mode MUST be translation. Translate the entire input into ${targetName}; never summarize, omit, deduplicate, or combine repeated content.
- mode=none and mode=correction are valid ONLY when sourceLang is ${targetLang}. Then use mode=correction only for a clear, objective grammar, spelling, inflection, agreement, or wrong-word error. Make the smallest defensible correction and never invent missing meaning. Otherwise use mode=none.
- Do not correct capitalization, punctuation, slang, abbreviations, dialect, colloquial phrasing, tone, style, or another acceptable wording unless it creates a clear language error or changes the intended meaning.
- mode is determined only from sourceLang compared with the viewer's learning language. It never depends on whether the viewer authored or received the message.
- For mode=correction, "translation" is the corrected ${targetName} text, "explanation" is one concise ${interfaceName} sentence, and confidence is low, medium, or high. Use low/medium when context makes the correction ambiguous.
- For mode=none, "translation" exactly equals the trimmed input and explanation/confidence are null.
- For mode=translation, explanation/confidence are null.
- "interfaceText" is the full message in ${interfaceName}, based on the corrected meaning when mode=correction.
- mode=none applies only to correction of the ${targetName} learning line. When ${interfaceName} is a different language, interfaceText must still translate the complete message into ${interfaceName}; do not copy the ${targetName} text into interfaceText.
- If sourceLang is ${interfaceLang} and differs from ${targetLang}, "interfaceText" must exactly equal the trimmed input, including any mistakes.
- If ${interfaceLang} and ${targetName} are the same language, "interfaceText" must exactly equal "translation".
- sourceLang must be one of the listed codes, or ${OTHER_SOURCE_LANG} for any other input language.
- For every mode, concatenating every tokens[].text must exactly reproduce "translation".
- Content tokens are segments of the translated/corrected text and include a short ${interfaceName} gloss.
- Whitespace, punctuation, and emoji use isContent=false and omit glosses.
- ${romanGuidance}`;
}
