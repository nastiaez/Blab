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

export type FormParticipantContext = {
  viewerName: string;
  partnerName: string;
  messageAuthor: "viewer" | "partner";
  viewerForm: "feminine" | "masculine" | null;
  partnerForm: "feminine" | "masculine" | null;
  tone: "informal" | "respectful";
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
  formContext,
  retryGuidance = "",
}: {
  sourceLang: string;
  targetLang: string;
  interfaceLang: string;
  text: string;
  context?: TranslationContextMessage[];
  formContext?: FormParticipantContext;
  retryGuidance?: string;
}): Array<{ role: "system" | "user"; content: string }> {
  const contextText = context.length === 0
    ? ""
    : `\n\nRecent chat context, oldest to newest. Use context only to resolve omitted subjects, explicit pronouns/gender metadata, family references, and dates. Use the supplied participant names only to suggest a grammatical form when no saved form exists; never change which person the sentence describes based on a name. Do not translate this context block; translate only the current user message.\n${
      context
        .map((entry) => `${entry.speaker}: ${entry.text}`)
        .join("\n")
    }`;
  return [
    {
      role: "system",
      content:
        systemPrompt(sourceLang, targetLang, interfaceLang, formContext) +
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
          minItems: 1,
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
        formAlternatives: {
          type: ["object", "null"],
          additionalProperties: false,
          properties: {
            before: { type: "string" },
            feminine: { type: "string", minLength: 1 },
            masculine: { type: "string", minLength: 1 },
            after: { type: "string" },
            subjectName: { type: "string", minLength: 1 },
            subjectIsViewer: { type: "boolean" },
            suggestedForm: {
              type: ["string", "null"],
              enum: ["feminine", "masculine", null],
            },
          },
          required: [
            "before",
            "feminine",
            "masculine",
            "after",
            "subjectName",
            "subjectIsViewer",
            "suggestedForm",
          ],
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
        "formAlternatives",
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

export const FORM_AUDIT_RESPONSE_FORMAT = {
  type: "json_schema",
  json_schema: {
    name: "blab_grammatical_form_audit",
    strict: true,
    schema: {
      type: "object",
      additionalProperties: false,
      properties: {
        requiresChoice: { type: "boolean" },
        suggestedForm: {
          type: ["string", "null"],
          enum: ["feminine", "masculine", null],
        },
        subjectIsViewer: { type: ["boolean", "null"] },
        before: { type: ["string", "null"] },
        feminine: { type: ["string", "null"] },
        masculine: { type: ["string", "null"] },
        after: { type: ["string", "null"] },
      },
      required: [
        "requiresChoice",
        "suggestedForm",
        "subjectIsViewer",
        "before",
        "feminine",
        "masculine",
        "after",
      ],
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

const LATIN_TARGETS = new Set(["en", "nl", "fr", "de", "it", "pt", "es", "tr"]);
export const INTERFACE_LANGS = new Set(["en", "uk", "de", "es"]);
export const OTHER_SOURCE_LANG = "other";
export const GENDER_ADDRESS_RULES =
  `Use an explicit saved grammatical form first. Otherwise suggest feminine or masculine from the affected person’s supplied name; use feminine if the name is ambiguous. For example, Alice suggests feminine and Bob suggests masculine; Alex is ambiguous and defaults to feminine. This is a provisional translation form, not confirmed identity. Do not infer it from message topic or writing style.
Use a saved grammatical form only for the participant it belongs to.
If a natural translation needs feminine/masculine agreement, return the two complete natural alternatives in formAlternatives. Do not replace them with an awkward neutral rewrite and never use parentheses or slash alternatives in translation.
This applies to every target language where a natural sentence genuinely changes, including French, Hindi, Italian, Portuguese, Spanish, Ukrainian, and conditionally Dutch, German, and Tamil. English and Turkish normally do not need form alternatives.
Preserve authored formality. When it is not explicit, use the supplied per-chat tone: informal or respectful.`;
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
  formAlternatives: FormAlternatives | null;
};

export type FormAlternatives = {
  before: string;
  feminine: string;
  masculine: string;
  after: string;
  subjectName: string;
  subjectIsViewer: boolean;
  suggestedForm?: "feminine" | "masculine";
  subjectRole?: "author" | "recipient";
};

// US-042: unquoted, single-subject direct English is deterministic; other
// references are handled by the agreement audit rather than guessed by name.
export function directSubjectRole(text: string): "author" | "recipient" | null {
  const directPatterns = [
    /^(?:did|do) (?:i|you) (?:go|visit)(?: (?:to )?(?:the )?(?:supermarket|museum|store|park|school|office))?(?: (?:yesterday|today|last night|this morning))?[.!?]?$/i,
    /^(?:(?:i|you) (?:am|are|was|were|feel|felt)|(?:am|are|was|were) (?:i|you)) (?:very |so )?(?:tired|happy|sad|ready|exhausted|proud|angry|excited|afraid|alone)(?: (?:yesterday|today|last night|this morning))?[.!?]?$/i,
  ];
  const input = text.trim();
  if (!directPatterns.some((pattern) => pattern.test(input))) return null;
  return /\bi\b/i.test(input) ? "author" : "recipient";
}

export function normalizeFormSubject(
  a: FormAlternatives,
  context: FormParticipantContext,
  source: string,
): FormAlternatives {
  const role = directSubjectRole(source) ??
    (a.subjectIsViewer === (context.messageAuthor === "viewer")
      ? "author"
      : "recipient");
  const viewer = role === "author"
    ? context.messageAuthor === "viewer"
    : context.messageAuthor !== "viewer";
  return {
    ...a,
    subjectRole: role,
    subjectIsViewer: viewer,
    subjectName: viewer ? context.viewerName : context.partnerName,
    suggestedForm: a.suggestedForm ?? "feminine",
  };
}

const FORM_RELEVANT_TARGET_LANGS = new Set([
  "nl",
  "fr",
  "de",
  "hi",
  "it",
  "pt",
  "es",
  "ta",
  "uk",
]);

/// The first provider response is not allowed to silently settle an eligible
/// gendered target while either participant still has no saved form. A second,
/// explicit audit may confirm that the sentence is naturally form-neutral.
export function missingFormAlternativesNeedsAudit(
  result: TranslationResult,
  targetLang: string,
  _formContext: FormParticipantContext,
  _attempt: number,
): boolean {
  return result.mode === "translation" &&
    FORM_RELEVANT_TARGET_LANGS.has(targetLang);
}

export type FormAuditResult = {
  requiresChoice: boolean;
  subjectIsViewer: boolean | null;
  before: string | null;
  feminine: string | null;
  masculine: string | null;
  after: string | null;
  suggestedForm?: "feminine" | "masculine";
};

export function parseFormAuditResult(content: string): FormAuditResult | null {
  const firstBrace = content.indexOf("{");
  const lastBrace = content.lastIndexOf("}");
  if (firstBrace < 0 || lastBrace <= firstBrace) return null;
  let raw: unknown;
  try {
    raw = JSON.parse(content.slice(firstBrace, lastBrace + 1));
  } catch {
    return null;
  }
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    return null;
  }
  const value = raw as Record<string, unknown>;
  if (
    typeof value.requiresChoice !== "boolean" ||
    value.subjectIsViewer !== null &&
      typeof value.subjectIsViewer !== "boolean" ||
    value.before !== null && typeof value.before !== "string" ||
    value.feminine !== null && typeof value.feminine !== "string" ||
    value.masculine !== null && typeof value.masculine !== "string" ||
    value.after !== null && typeof value.after !== "string"
  ) return null;
  if (value.requiresChoice) {
    if (
      typeof value.subjectIsViewer !== "boolean" ||
      typeof value.before !== "string" ||
      typeof value.feminine !== "string" || value.feminine.trim() === "" ||
      typeof value.masculine !== "string" || value.masculine.trim() === "" ||
      typeof value.after !== "string" ||
      value.feminine === value.masculine
    ) return null;
  } else if (
    value.subjectIsViewer !== null || value.before !== null ||
    value.feminine !== null || value.masculine !== null || value.after !== null
  ) {
    return null;
  }
  return {
    requiresChoice: value.requiresChoice,
    subjectIsViewer: value.requiresChoice
      ? value.subjectIsViewer as boolean
      : null,
    before: value.requiresChoice ? value.before as string : null,
    feminine: value.requiresChoice ? value.feminine as string : null,
    masculine: value.requiresChoice ? value.masculine as string : null,
    after: value.requiresChoice ? value.after as string : null,
    suggestedForm: value.suggestedForm === "masculine"
      ? "masculine"
      : "feminine",
  };
}

export function confirmedFormAlternativesMatchAudit(
  alternatives: FormAlternatives | null,
  audit: FormAuditResult,
): boolean {
  return audit.requiresChoice &&
    alternatives !== null &&
    alternatives.subjectIsViewer === audit.subjectIsViewer &&
    alternatives.before === audit.before &&
    alternatives.feminine === audit.feminine &&
    alternatives.masculine === audit.masculine &&
    alternatives.after === audit.after;
}

export function formAlternativesFromConfirmedAudit(
  result: TranslationResult,
  audit: FormAuditResult,
  formContext: FormParticipantContext,
): FormAlternatives | null {
  if (
    result.mode !== "translation" || !audit.requiresChoice ||
    typeof audit.subjectIsViewer !== "boolean" ||
    typeof audit.before !== "string" ||
    typeof audit.feminine !== "string" ||
    typeof audit.masculine !== "string" ||
    typeof audit.after !== "string" ||
    `${audit.before}${audit.feminine}${audit.after}` !== result.translation
  ) return null;
  return {
    before: audit.before,
    feminine: audit.feminine,
    masculine: audit.masculine,
    after: audit.after,
    subjectName: audit.subjectIsViewer
      ? formContext.viewerName
      : formContext.partnerName,
    subjectIsViewer: audit.subjectIsViewer,
    suggestedForm: audit.suggestedForm ?? "feminine",
  };
}

export function formAuditSystemPrompt(
  sourceLang: string,
  targetLang: string,
  formContext: FormParticipantContext,
): string {
  const sourceName = LANG_NAMES[sourceLang] ?? sourceLang;
  const targetName = LANG_NAMES[targetLang] ?? targetLang;
  return `You verify grammatical agreement in one translated chat message.
The source language is ${sourceName} (${sourceLang}); the target is ${targetName} (${targetLang}).
Viewer name: ${formContext.viewerName}. Partner name: ${formContext.partnerName}.
The current message author is the ${formContext.messageAuthor}. In direct first/second-person speech, “I” refers to ${
    formContext.messageAuthor === "viewer"
      ? formContext.viewerName
      : formContext.partnerName
  }; “you” refers to ${
    formContext.messageAuthor === "viewer"
      ? formContext.partnerName
      : formContext.viewerName
  }. Determine the subject before suggesting a form. Never label an incoming “you” sentence as the sender’s form.
Viewer saved form: ${
    formContext.viewerForm ?? "not set"
  }. Partner saved form: ${formContext.partnerForm ?? "not set"}.

Decide whether the shortest complete natural target-language sentence changes between feminine and masculine for the viewer or partner. Check verbs, adjectives, participles, pronouns, agreement, and gendered person nouns together. Do not treat masculine as a generic default. Do not avoid a real choice with an awkward neutral rewrite. For suggestedForm use the affected person’s saved form first, otherwise suggest from their supplied name; when unclear use feminine. For example, Alice suggests feminine, Bob suggests masculine, and an ambiguous Alex defaults to feminine. Do not change the sentence to avoid a form choice and do not infer from topic or writing style.

Return strict JSON only: {"requiresChoice":true|false,"subjectIsViewer":true|false|null,"before":"shared prefix"|null,"feminine":"shortest complete feminine fragment"|null,"masculine":"shortest complete masculine fragment"|null,"after":"shared suffix"|null,"suggestedForm":"feminine"|"masculine"|null}.
When a natural choice is required, identify the affected participant and split the target sentence around the shortest complete fragment containing every linked agreement change. Keep all identical text in before/after. For a single changing verb such as “Ти ходила/ходив до…”, return before="Ти ", feminine="ходила", masculine="ходив", and after=" до…"—never repeat the whole sentence in either option. When no choice is required, the participant and all four text fields must be null.`;
}

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
  // Word metadata powers optional tap-to-explain affordances. A provider can
  // return a valid full-message translation while omitting or corrupting that
  // metadata; parseProviderResult already degrades it to an empty token list.
  // Never turn a usable translation into a request failure for that reason.
  return result.mode === "translation" &&
    result.sourceLang !== targetLang &&
    result.translation.trim().toLocaleLowerCase() ===
      sourceText.trim().toLocaleLowerCase();
}

/// Same-language corrections must preserve the complete authored message.
/// A provider occasionally compresses a multi-sentence caption into only its
/// last question, which is not a correction and must be retried.
export function correctionNeedsRetry(
  result: TranslationResult,
  sourceText: string,
): boolean {
  if (result.mode !== "correction") return false;
  const words = (value: string) =>
    value.toLocaleLowerCase()
      .replace(/[’‘]/g, "'")
      .match(/[\p{L}\p{M}\p{N}']+/gu) ?? [];
  const sourceWords = words(sourceText);
  const correctedWords = words(result.translation);
  if (sourceWords.length === 0 || correctedWords.length === 0) return true;
  if (correctedWords.length < Math.max(1, sourceWords.length - 1)) return true;

  const distance = (a: string, b: string): number => {
    const row = Array.from({ length: b.length + 1 }, (_, index) => index);
    for (let i = 1; i <= a.length; i++) {
      let diagonal = row[0];
      row[0] = i;
      for (let j = 1; j <= b.length; j++) {
        const previous = row[j];
        row[j] = a[i - 1] === b[j - 1]
          ? diagonal
          : Math.min(diagonal, row[j - 1], row[j]) + 1;
        diagonal = previous;
      }
    }
    return row[b.length];
  };
  const similar = (a: string, b: string) =>
    a === b || distance(a, b) <= Math.max(1, Math.floor(a.length * 0.4));

  let cursor = 0;
  let matched = 0;
  for (const sourceWord of sourceWords) {
    while (
      cursor < correctedWords.length &&
      !similar(sourceWord, correctedWords[cursor])
    ) cursor++;
    if (cursor < correctedWords.length) {
      matched++;
      cursor++;
    }
  }
  return matched < Math.max(1, sourceWords.length - 1);
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
    formAlternatives: parseFormAlternatives(raw.formAlternatives),
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
  if (result.mode !== "translation") {
    result.formAlternatives = null;
  } else if (result.formAlternatives !== null) {
    const alternatives = result.formAlternatives;
    if (
      `${alternatives.before}${alternatives.feminine}${alternatives.after}` !==
        result.translation ||
      alternatives.feminine === alternatives.masculine
    ) return null;
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
  if (validTokens) {
    const repairedTokens = repairTokensToTranslation(
      result.tokens,
      result.translation,
      targetLang,
    );
    if (repairedTokens !== null) {
      result.tokens = repairedTokens;
      reproduced = repairedTokens.map((token) => token.text as string).join("");
    }
  }
  if (!validTokens || reproduced !== result.translation) {
    // Token metadata powers optional word lookup. A malformed token list must
    // not hide an otherwise valid full-message translation.
    result.tokens = [];
  }
  return result;
}

function repairTokensToTranslation(
  tokens: unknown[],
  translation: string,
  targetLang: string,
): Array<Record<string, unknown>> | null {
  const isWordCharacter = (character: string) =>
    /[\p{L}\p{M}\p{N}]/u.test(character);
  const contentTokens = tokens.filter((token) =>
    (token as { isContent?: unknown }).isContent === true
  ) as Array<Record<string, unknown>>;
  if (contentTokens.length === 0) return null;

  const contentKeys = contentTokens.map((token) =>
    Array.from(token.text as string).filter(isWordCharacter).join("")
  );
  if (contentKeys.some((key) => key.length === 0)) return null;
  const translationCharacters = Array.from(translation);
  const translationKey = translationCharacters.filter(isWordCharacter).join("");
  if (contentKeys.join("") !== translationKey) return null;

  const repaired: Array<Record<string, unknown>> = [];
  let cursor = 0;
  for (let index = 0; index < contentTokens.length; index++) {
    const separatorStart = cursor;
    while (
      cursor < translationCharacters.length &&
      !isWordCharacter(translationCharacters[cursor])
    ) {
      cursor++;
    }
    if (cursor > separatorStart) {
      repaired.push({
        "text": translationCharacters.slice(separatorStart, cursor).join(""),
        "gloss": null,
        "roman": null,
        "isContent": false,
      });
    }

    const contentStart = cursor;
    let matchedKey = "";
    while (
      cursor < translationCharacters.length &&
      matchedKey.length < contentKeys[index].length
    ) {
      const character = translationCharacters[cursor++];
      if (isWordCharacter(character)) matchedKey += character;
    }
    if (matchedKey !== contentKeys[index]) return null;
    const text = translationCharacters.slice(contentStart, cursor).join("");
    const roman = contentTokens[index].roman;
    repaired.push({
      ...contentTokens[index],
      "text": text,
      "roman": typeof roman === "string" && roman.trim().length > 0
        ? roman
        : LATIN_TARGETS.has(targetLang)
        ? text
        : null,
    });
  }

  if (cursor < translationCharacters.length) {
    repaired.push({
      "text": translationCharacters.slice(cursor).join(""),
      "gloss": null,
      "roman": null,
      "isContent": false,
    });
  }
  return repaired;
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

function parseFormAlternatives(value: unknown): FormAlternatives | null {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    return null;
  }
  const raw = value as Record<string, unknown>;
  if (
    typeof raw.before !== "string" ||
    typeof raw.feminine !== "string" || raw.feminine.trim() === "" ||
    typeof raw.masculine !== "string" || raw.masculine.trim() === "" ||
    typeof raw.after !== "string" ||
    typeof raw.subjectName !== "string" || raw.subjectName.trim() === "" ||
    typeof raw.subjectIsViewer !== "boolean"
  ) return null;
  return {
    before: raw.before,
    feminine: raw.feminine,
    masculine: raw.masculine,
    after: raw.after,
    subjectName: raw.subjectName,
    subjectIsViewer: raw.subjectIsViewer,
    suggestedForm: raw.suggestedForm === "masculine" ? "masculine" : "feminine",
  };
}

export function systemPrompt(
  sourceLang: string,
  targetLang: string,
  interfaceLang: string,
  formContext?: FormParticipantContext,
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
  const romanGuidance =
    `For each content token include "roman", a Latin-script transliteration. For a Latin-script target word, repeat the written word when no script conversion is needed.`;

  const formInstruction = formContext === undefined
    ? "No participant grammatical-form data is available."
    : `Participants: viewer=${formContext.viewerName} (saved form: ${
      formContext.viewerForm ?? "not set"
    }); partner=${formContext.partnerName} (saved form: ${
      formContext.partnerForm ?? "not set"
    }); current message author=${formContext.messageAuthor}; chat tone=${formContext.tone}. For a direct first/second-person message, "I" normally refers to the author and "you" to the other participant.`;
  return `You normalize a message for a language-learning chat.

${sourceInstruction}
The viewer's learning language is ${targetName} (${targetLang}).
The viewer's interface language is ${interfaceName} (${interfaceLang}).
${formInstruction}

Return strict JSON only:
{
  "mode": "<translation, correction, or none>",
  "sourceLang": "<detected supported code, or ${OTHER_SOURCE_LANG}>",
  "translation": "<the complete ${targetName} learning-language line>",
  "interfaceText": "<the complete ${interfaceName} interface-language line>",
  "explanation": "<short ${interfaceName} correction explanation, or null>",
  "confidence": "<low, medium, high, or null>",
  "formAlternatives": { "before": "<unchanged prefix>", "feminine": "<complete feminine affected fragment>", "masculine": "<complete masculine affected fragment>", "after": "<unchanged suffix>", "subjectName": "<viewer or partner display name>", "subjectIsViewer": true, "suggestedForm": "feminine" },
  "tokens": [
    { "text": "<segment of translation>", "gloss": "<1-3 word ${interfaceName} gloss>", "roman": "<romanization>", "isContent": true },
    { "text": " ", "isContent": false }
  ]
}

Rules:
- Preserve meaning and tone. Keep URLs, @mentions, hashtags, code, numbers, and emoji unchanged, and preserve names' identity rather than translating their meaning; transliterate a confidently identified name when the target script differs. Move protected content with the surrounding sentence when the target language needs a different natural word order.
- Treat repeated letters, stretched vowels or consonants, playful capitalization, and similar chat styling as expressive spelling of the underlying language. Normalize these only while detecting the source language; never label them as unsupported or correct them as mistakes. Preserve the expressive tone in the translated line when the target language has a natural equivalent.
- A likely personal name is not an unsupported language. Keep its identity, and when the target script differs, transliterate it rather than translating its meaning. Use conversation context and the supplied participant names when available; do not infer a name from capitalization alone.
- Treat meaning-bearing chat abbreviations such as brb and ttyl as language: translate their meaning when the target language has a natural equivalent; otherwise preserve them.
- Preserve paragraph breaks exactly. If the input is one paragraph, translation and interfaceText must also be one paragraph with no newline characters.
- ${GENDER_ADDRESS_RULES.replaceAll("\n", "\n- ")}
- First detect sourceLang, then choose exactly one mode.
- If sourceLang differs from ${targetLang}, including sourceLang=${OTHER_SOURCE_LANG}, mode MUST be translation. Translate the entire input into ${targetName}; never summarize, omit, deduplicate, or combine repeated content.
- mode=none and mode=correction are valid ONLY when sourceLang is ${targetLang}. Then carefully check the complete input for real learning mistakes: grammar, spelling, inflection, agreement, word order, missing/extra words, or wrong-word errors. Even one wrong word or misspelled word is enough for mode=correction. Make the smallest defensible correction and never invent missing meaning. Otherwise use mode=none.
- Do not correct capitalization, punctuation, slang, abbreviations, dialect, colloquial phrasing, tone, style, or another acceptable wording unless it creates a clear language error or changes the intended meaning.
- Never create correction marks for capitalization, noun capitalization, apostrophes, commas, terminal punctuation, or spacing. Apply those mechanical fixes silently in translation/interfaceText when needed.
- mode is determined only from sourceLang compared with the viewer's learning language. It never depends on whether the viewer authored or received the message.
- For mode=correction, "translation" is the corrected ${targetName} text, "explanation" is one concise ${interfaceName} sentence, and confidence is low, medium, or high. Use low/medium when context makes the correction ambiguous.
- For mode=none, "translation" exactly equals the trimmed input and explanation/confidence are null.
- For mode=translation, explanation/confidence are null.
- Set formAlternatives to null unless the target sentence genuinely requires a feminine/masculine choice for the viewer or partner even when a saved form exists. When it is required, set translation to the feminine rendering, and concatenate before + feminine + after to reproduce translation exactly. feminine and masculine must be complete, natural alternatives for the same shortest understandable affected fragment; include every linked agreement change together. subjectIsViewer identifies the affected participant and subjectName is their display name. Set suggestedForm from their saved form first, otherwise their name, or feminine if unclear; it never changes the identity of the affected participant.
- This is a required output rule, not a suggestion to make wording neutral. For example, ONLY when the viewer authored English "What did you do yesterday?" and both forms are not set, Ukrainian MUST return translation="Що ти робила вчора?" and formAlternatives={"before":"Що ти ","feminine":"робила","masculine":"робив","after":" вчора?","subjectName":"<partner name>","subjectIsViewer":false}. When the partner authored that same question, subjectIsViewer MUST instead be true and subjectName MUST be the viewer’s name. Apply the same rule to the natural feminine/masculine fragment in every supported target language; French/Hindi may need a multi-word fragment.
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
