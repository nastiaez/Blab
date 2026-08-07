export const MAX_CHARS = 2000;

export const OPENROUTER_PROVIDER = {
  allow_fallbacks: true,
  require_parameters: true,
  data_collection: "deny",
  zdr: true,
} as const;

export type TranslationProvider = "openrouter" | "openai";

export type ProviderCredential = {
  provider: TranslationProvider;
  apiKey: string;
  model: string;
  useOpenRouterProviderPolicy: boolean;
};

export type TranslationContextMessage = {
  speaker: "viewer" | "partner";
  text: string;
};

const DEFAULT_OPENROUTER_MODEL = "openai/gpt-4o-mini";
const DEFAULT_OPENAI_MODEL = "gpt-4o-mini";

export function providerCredentials(env: {
  openRouterKey?: string | null;
  openAiKey?: string | null;
  openRouterModel?: string | null;
  openAiModel?: string | null;
  openRouterProviderPolicy?: string | null;
  environment?: string | null;
}): ProviderCredential[] {
  const providers: ProviderCredential[] = [];
  const openRouterKey = env.openRouterKey?.trim();
  const openAiKey = env.openAiKey?.trim();
  const openRouterModel = env.openRouterModel?.trim() ||
    DEFAULT_OPENROUTER_MODEL;
  const openAiModel = env.openAiModel?.trim() || DEFAULT_OPENAI_MODEL;
  const disableOpenRouterProviderPolicy =
    env.environment?.trim().toLocaleLowerCase() === "local" &&
    ["0", "false"].includes(
      env.openRouterProviderPolicy?.trim().toLocaleLowerCase() ?? "",
    );
  const useOpenRouterProviderPolicy = !disableOpenRouterProviderPolicy;
  if (openRouterKey) {
    providers.push({
      provider: "openrouter",
      apiKey: openRouterKey,
      model: openRouterModel,
      useOpenRouterProviderPolicy,
    });
  }
  if (openAiKey) {
    providers.push({
      provider: "openai",
      apiKey: openAiKey,
      model: openAiModel,
      useOpenRouterProviderPolicy: false,
    });
  }
  return providers;
}

export function providerMessages({
  sourceLang,
  targetLang,
  interfaceLang,
  text,
  context = [],
  retryGuidance = "",
}: {
  sourceLang: string;
  targetLang: string;
  interfaceLang: string;
  text: string;
  context?: TranslationContextMessage[];
  retryGuidance?: string;
}): Array<{ role: "system" | "user"; content: string }> {
  const contextText = context.length === 0
    ? ""
    : `\n\nRecent chat context, oldest to newest. Use context only to resolve omitted subjects, explicit pronouns/gender metadata, family references, and dates. Never infer gender from names or casual text in this context. Do not translate this context block; translate only the current user message.\n${
      context
        .map((entry) => `${entry.speaker}: ${entry.text}`)
        .join("\n")
    }`;
  return [
    {
      role: "system",
      content: systemPrompt(sourceLang, targetLang, interfaceLang) +
        contextText +
        retryGuidance,
    },
    { role: "user", content: text },
  ];
}

export const TRANSLATION_RESPONSE_FORMAT = {
  type: "json_schema",
  json_schema: {
    name: "blab_translation",
    strict: true,
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        mode: { type: "string", enum: ["translation", "correction", "none"] },
        sourceLang: {
          type: "string",
          enum: [
            "en",
            "ta",
            "uk",
            "es",
            "de",
            "fr",
            "it",
            "pt",
            "nl",
            "tr",
            "hi",
            "other",
          ],
        },
        translation: { type: "string", minLength: 1 },
        interfaceText: { type: "string", minLength: 1 },
        explanation: { type: ["string", "null"] },
        confidence: {
          type: ["string", "null"],
          enum: ["low", "medium", "high", null],
        },
        tokens: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            properties: {
              text: { type: "string" },
              gloss: { type: ["string", "null"] },
              roman: { type: ["string", "null"] },
              isContent: { type: "boolean" },
            },
            required: ["text", "gloss", "roman", "isContent"],
          },
        },
      },
      required: [
        "mode",
        "sourceLang",
        "translation",
        "interfaceText",
        "explanation",
        "confidence",
        "tokens",
      ],
    },
  },
} as const;

export const INTERFACE_RESPONSE_FORMAT = {
  type: "json_schema",
  json_schema: {
    name: "blab_interface_translation",
    strict: true,
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        interfaceText: { type: "string", minLength: 1 },
      },
      required: ["interfaceText"],
    },
  },
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
export const GENDER_ADDRESS_RULES =
  `Never guess gender from a name, profile name, username, message topic, or text style.
Use gendered wording only when explicit pronouns or gender metadata are provided.
If the source language is ambiguous, use neutral wording that avoids adding gender.
Do not use parenthetical or slash gender alternatives such as "був(ла)", "радий(а)", "був/була", or "радий/рада"; rewrite the sentence with impersonal neutral wording instead.
Preserve informal/formal address exactly when the source marks it. Keep "du" informal and "Sie" formal in German, and keep equivalent formality distinctions in other languages. Address example: Ukrainian "Ти дивишся..." to German: prefer informal "Du schaust..." over formal "Sie schauen...".
Gender examples: English "I was happy to help" to Ukrainian: prefer "Мені було приємно допомогти" over gendered "Я був радий/була рада допомогти". English "I was glad to see you" to Ukrainian: prefer "Мені було приємно побачитись з тобою" over stiff or gendered wording. English "I am your friend" to Ukrainian: prefer "Ми з тобою друзі" over guessing "Я твій друг" or "Я твоя подруга". English "I am your friend" to German: prefer "Ich bin mit dir befreundet" over guessing "Freund" or "Freundin".`;
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
  if (result.interfaceText.trim().length === 0) return true;
  return targetLang !== interfaceLang &&
    result.interfaceText.trim().toLocaleLowerCase() ===
      result.translation.trim().toLocaleLowerCase() &&
    /\p{L}/u.test(result.translation);
}

/// A provider sometimes returns the untranslated source as "translation"
/// while still filling in per-word gloss/roman tokens, as if word-level aid
/// were a substitute for the required full-sentence translation. That must
/// never reach the viewer as their learning-language line.
export function translationNeedsRetry(
  result: TranslationResult,
  targetLang: string,
  sourceText: string,
): boolean {
  return result.mode === "translation" &&
    result.sourceLang !== targetLang &&
    result.translation.trim().toLocaleLowerCase() ===
      sourceText.trim().toLocaleLowerCase();
}

export function genderedAmbiguityNeedsRetry(
  result: TranslationResult,
  sourceLang: string,
  targetLang: string,
  sourceText = "",
): boolean {
  if (
    result.mode !== "translation" ||
    result.sourceLang !== "en" ||
    sourceLang !== "auto" && sourceLang !== "en" ||
    targetLang !== "uk"
  ) return false;
  const ukrainianLetters = "A-Za-zА-Яа-яІіЇїЄєҐґ";
  const parentheticalGender = new RegExp(
    `[${ukrainianLetters}]+\\([${ukrainianLetters}]+\\)`,
    "u",
  );
  const slashGender = new RegExp(
    `[${ukrainianLetters}]+\\/[${ukrainianLetters}]+`,
    "u",
  );
  if (
    parentheticalGender.test(result.translation) ||
    slashGender.test(result.translation)
  ) return true;
  if (/\b(he|him|his|she|her|hers)\b/i.test(sourceText)) return false;
  return /(^|[^\p{L}])(друг|подруга)($|[^\p{L}])/iu.test(
    result.translation,
  );
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
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    return null;
  }
  const raw = parsed as Record<string, unknown>;
  if (
    typeof raw.translation !== "string" ||
    raw.translation.trim().length === 0
  ) return null;

  const sourceLang = normalizeSourceLang(raw.sourceLang);
  const explanation = typeof raw.explanation === "string" &&
      raw.explanation.trim().length > 0
    ? raw.explanation
    : null;
  const confidence = typeof raw.confidence === "string" &&
      CORRECTION_CONFIDENCE.has(raw.confidence)
    ? raw.confidence as CorrectionConfidence
    : null;
  const result: TranslationResult = {
    mode: typeof raw.mode === "string" && LEARNING_AID_MODES.has(raw.mode)
      ? raw.mode as LearningAidMode
      : "translation",
    sourceLang,
    translation: normalizeProviderLineBreaks(raw.translation, text),
    interfaceText: typeof raw.interfaceText === "string"
      ? normalizeProviderLineBreaks(raw.interfaceText, text)
      : "",
    explanation,
    confidence,
    tokens: Array.isArray(raw.tokens) ? raw.tokens : [],
  };
  const sourceMatchesTarget = result.sourceLang === targetLang;
  if (!sourceMatchesTarget) {
    result.mode = "translation";
    result.explanation = null;
    result.confidence = null;
  } else if (result.translation === text) {
    result.mode = "none";
    result.explanation = null;
    result.confidence = null;
  } else if (result.explanation !== null && result.confidence !== null) {
    result.mode = "correction";
  } else {
    // A same-language rewrite without correction metadata is not safe to
    // present as a correction. Preserve the authored line and repair only
    // the interface-language rendering below.
    result.mode = "none";
    result.translation = text;
    result.interfaceText = interfaceLang === targetLang ? text : "";
    result.explanation = null;
    result.confidence = null;
    result.tokens = [];
  }
  // These display lines are fully determined by trusted inputs. Normalize
  // them instead of rejecting an otherwise valid provider translation when
  // the model rewrites a typo or returns two slightly different copies.
  if (interfaceLang === targetLang) {
    result.interfaceText = result.translation;
  } else if (sourceLang === interfaceLang) {
    // Same-language display line: the DB requires this to exactly match the
    // original message, so never trust the provider's copy of it (models
    // routinely "fix" punctuation/capitalization, which breaks that check).
    result.interfaceText = text;
  } else if (result.interfaceText.trim().length === 0) {
    result.interfaceText = text;
  }
  if (result.mode === "none") {
    result.translation = text;
    result.explanation = null;
    result.confidence = null;
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
        /\s/.test((token as { text: string }).text.trim()) ||
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

function normalizeProviderLineBreaks(
  value: string,
  sourceText: string,
): string {
  const source = sourceText.trim();
  if (/[\r\n]/.test(source)) return value;
  return value.replace(/\s*[\r\n]+\s*/g, " ");
}

export function providerResultFailureReason(content: string): string {
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
    return "invalid_response_json";
  }
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    return "invalid_response_shape";
  }
  const translation = (parsed as Record<string, unknown>).translation;
  if (typeof translation !== "string" || translation.trim().length === 0) {
    return "missing_translation";
  }
  return "contract_semantics";
}

function normalizeSourceLang(value: unknown): string {
  if (typeof value !== "string") return OTHER_SOURCE_LANG;
  const normalized = value.trim().toLocaleLowerCase();
  if (normalized in LANG_NAMES) return normalized;
  if (normalized === OTHER_SOURCE_LANG) return OTHER_SOURCE_LANG;
  for (const [code, name] of Object.entries(LANG_NAMES)) {
    if (name.toLocaleLowerCase() === normalized) return code;
  }
  return OTHER_SOURCE_LANG;
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
- Preserve paragraph breaks exactly. If the input is one paragraph, translation and interfaceText must also be one paragraph with no newline characters.
- ${GENDER_ADDRESS_RULES.replaceAll("\n", "\n- ")}
- First detect sourceLang, then choose exactly one mode.
- If sourceLang differs from ${targetLang}, including sourceLang=${OTHER_SOURCE_LANG}, mode MUST be translation. Translate the entire input into ${targetName}; never summarize, omit, deduplicate, or combine repeated content.
- mode=none and mode=correction are valid ONLY when sourceLang is ${targetLang}. Then carefully check the complete input for real learning mistakes: grammar, spelling, inflection, agreement, word order, missing/extra words, or wrong-word errors. Even one wrong word or misspelled word is enough for mode=correction. Make the smallest defensible correction and never invent missing meaning. Otherwise use mode=none.
- Do not correct capitalization, punctuation, slang, abbreviations, dialect, colloquial phrasing, tone, style, or another acceptable wording unless it creates a clear language error or changes the intended meaning.
- mode is determined only from sourceLang compared with the viewer's learning language. It never depends on whether the viewer authored or received the message.
- For mode=correction, "translation" is the corrected ${targetName} text, "explanation" is one concise ${interfaceName} sentence, and confidence is low, medium, or high. Use low/medium when context makes the correction ambiguous.
- For mode=none, "translation" exactly equals the trimmed input and explanation/confidence are null.
- For mode=translation, explanation/confidence are null.
- "interfaceText" is the full message in ${interfaceName}, based on the corrected meaning when mode=correction or when a translated source has clear grammar, spelling, inflection, agreement, word order, missing/extra word, or wrong-word errors.
- mode=none applies only to correction of the ${targetName} learning line. When ${interfaceName} is a different language, interfaceText must still translate the complete message into ${interfaceName}; do not copy the ${targetName} text into interfaceText.
- If sourceLang is ${interfaceLang} and differs from ${targetLang}, "interfaceText" stays in ${interfaceName}; preserve the trimmed input when it is already correct, but fix clear language mistakes so the main chat shows clean communication.
- If ${interfaceLang} and ${targetName} are the same language, "interfaceText" must exactly equal "translation".
- sourceLang must be one of the listed codes, or ${OTHER_SOURCE_LANG} for any other input language.
- For every mode, concatenating every tokens[].text must exactly reproduce "translation".
- Content tokens are one translated/corrected word or one non-whitespace term at a time, never a phrase or full sentence, and include a short ${interfaceName} gloss.
- Whitespace, punctuation, and emoji use isContent=false and omit glosses.
- ${romanGuidance}`;
}

export function interfaceRepairSystemPrompt(
  targetLang: string,
  interfaceLang: string,
): string {
  const targetName = LANG_NAMES[targetLang] ?? targetLang;
  const interfaceName = LANG_NAMES[interfaceLang] ?? interfaceLang;
  return `Translate the complete user message from ${targetName} (${targetLang}) into ${interfaceName} (${interfaceLang}). Preserve meaning, tone, names, URLs, emoji, and punctuation.
${GENDER_ADDRESS_RULES}
Translate all translatable words even when the message is short. Return strict JSON only: {"interfaceText":"<complete ${interfaceName} translation>"}`;
}
