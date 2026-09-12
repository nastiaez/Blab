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
  sourceLang?: string | null;
};

export type FormParticipantContext = {
  viewerName: string;
  partnerName: string;
  messageAuthor: "viewer" | "partner";
  viewerForm: "feminine" | "masculine" | null;
  partnerForm: "feminine" | "masculine" | null;
  tone: "informal" | "respectful";
  authorPrimaryKnownLanguage?: string | null;
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
    : `\n\nRecent chat context, oldest to newest. For a genuinely ambiguous short current utterance, use recent messages from the same sender to resolve its source language. Otherwise use context only to resolve omitted subjects, explicit pronouns/gender metadata, family references, and dates. Use the supplied participant names only for a provisional grammatical-form suggestion; never change which person the sentence describes based on a name. Do not translate this context block; translate only the current user message.\n${
      context
        .map((entry) =>
          `${entry.speaker}${
            entry.sourceLang == null ? "" : ` [source=${entry.sourceLang}]`
          }: ${entry.text}`
        )
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

/// A short message whose source has already been resolved gets one focused
/// retry. Removing source detection and correction rules from that retry keeps
/// small complete utterances from being copied as if they were target text.
export function focusedTranslationRetryMessages({
  sourceLang,
  targetLang,
  interfaceLang,
  text,
  formContext,
}: {
  sourceLang: string;
  targetLang: string;
  interfaceLang: string;
  text: string;
  formContext?: FormParticipantContext;
}): Array<{ role: "system" | "user"; content: string }> | null {
  if (
    sourceLang === "auto" || sourceLang === targetLang ||
    !canRetrySourceClassification(text)
  ) return null;

  const sourceName = LANG_NAMES[sourceLang] ?? sourceLang;
  const targetName = LANG_NAMES[targetLang] ?? targetLang;
  const interfaceName = LANG_NAMES[interfaceLang] ?? interfaceLang;
  const participants = formContext === undefined
    ? ""
    : ` Participants: viewer=${formContext.viewerName}; partner=${formContext.partnerName}; current message author=${formContext.messageAuthor}; chat tone=${formContext.tone}.`;
  return [{
    role: "system",
    content:
      `Translate one complete chat utterance from ${sourceName} (${sourceLang}) into ${targetName} (${targetLang}). Treat it as a complete utterance even when it contains only one word. Translate its semantic meaning instead of copying its spelling. Return mode=translation and sourceLang=${sourceLang}. Put the complete natural ${targetName} translation in translation and the complete ${interfaceName} (${interfaceLang}) rendering in interfaceText. Translate meaning-bearing abbreviations into the target language's idiomatic local expression; for English OMG, translate the meaning “Oh my God” naturally and never transliterate the expanded English phrase. Preserve names and transliterate them when the target script differs. Preserve meaning, tone, URLs, mentions, numbers, emoji, and punctuation.${participants} Set explanation and confidence to null. Tokens must reproduce translation exactly, with one content token per word and Latin romanization for non-Latin words. Return formAlternatives only when the target genuinely requires a feminine/masculine choice; otherwise return null.`,
  }, { role: "user", content: text }];
}

const TOKEN_RESPONSE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  properties: {
    text: { type: "string" },
    gloss: { type: ["string", "null"] },
    roman: { type: ["string", "null"] },
    isContent: { type: "boolean" },
  },
  required: ["text", "gloss", "roman", "isContent"],
} as const;

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
          items: TOKEN_RESPONSE_SCHEMA,
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
            feminineTokens: {
              type: "array",
              minItems: 1,
              items: TOKEN_RESPONSE_SCHEMA,
            },
            masculineTokens: {
              type: "array",
              minItems: 1,
              items: TOKEN_RESPONSE_SCHEMA,
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
            "feminineTokens",
            "masculineTokens",
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
        feminineTokens: {
          type: ["array", "null"],
          minItems: 1,
          items: TOKEN_RESPONSE_SCHEMA,
        },
        masculineTokens: {
          type: ["array", "null"],
          minItems: 1,
          items: TOKEN_RESPONSE_SCHEMA,
        },
      },
      required: [
        "requiresChoice",
        "suggestedForm",
        "subjectIsViewer",
        "before",
        "feminine",
        "masculine",
        "after",
        "feminineTokens",
        "masculineTokens",
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
  `Suggest feminine or masculine from the affected person’s supplied name; use feminine if the name is ambiguous. For example, Alice suggests feminine and Bob suggests masculine; Alex is ambiguous and defaults to feminine. This is a provisional translation form, not confirmed identity. Do not infer it from message topic or writing style. Saved choices are private client state and must not be encoded in shared translation output.
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
  /// Internal retry signal. The provider claimed the authored input was
  /// already in the learning language, but returned a different rewrite
  /// without the metadata required for a valid correction.
  sourceClassificationConflict?: true;
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
  feminineTokens: TranslationToken[];
  masculineTokens: TranslationToken[];
};

export type TranslationToken = {
  text: string;
  gloss: string | null;
  roman: string | null;
  isContent: boolean;
};

type DirectSubjectRule = {
  sourceLang: string;
  authorStart: RegExp;
  recipientStart: RegExp;
  authorMarker: RegExp;
  recipientMarker: RegExp;
  unsafe: RegExp;
};

// Each rule recognizes grammatical person, not particular sentences. Explicit
// pronouns cover non-pro-drop languages; distinctive auxiliaries, conjugations,
// and agreement suffixes cover common omitted-pronoun clauses.
const DIRECT_SUBJECT_RULES: ReadonlyArray<DirectSubjectRule> = [
  {
    sourceLang: "en",
    authorStart:
      /^(?:i\b|(?:do|did|am|was|have|had|will|can|could|would|should)\s+i\b)/iu,
    recipientStart:
      /^(?:you\b|(?:do|did|are|were|have|had|will|can|could|would|should)\s+you\b)/iu,
    authorMarker: /\bi\b/iu,
    recipientMarker: /\byou\b/iu,
    unsafe:
      /\b(?:he|she|they|him|her|them|his|hers|their|because|while|although|that|who)\b/iu,
  },
  {
    sourceLang: "de",
    authorStart: /^ich\b/iu,
    recipientStart: /^du\b/iu,
    authorMarker: /\bich\b/iu,
    recipientMarker: /\bdu\b/iu,
    unsafe:
      /\b(?:er|sie|es|ihn|ihm|ihr|ihnen|dass|weil|während|obwohl|sagte|glaubte)\b/iu,
  },
  {
    sourceLang: "es",
    authorStart:
      /^(?:yo|estoy|soy|fui|he|había|voy|tengo|puedo|quiero|llegué)(?=\s|[.!?]|$)/iu,
    recipientStart:
      /^(?:tú|estás|eres|fuiste|eras|has|habías|vas|tienes|puedes|quieres|llegaste)(?=\s|[.!?]|$)/iu,
    authorMarker:
      /(?:^|\s)(?:yo|estoy|soy|fui|he|voy|tengo|puedo|quiero|llegué)(?=\s|[.!?]|$)/iu,
    recipientMarker:
      /(?:^|\s)(?:tú|estás|eres|fuiste|has|vas|tienes|puedes|quieres|llegaste)(?=\s|[.!?]|$)/iu,
    unsafe:
      /(?:^|\s)(?:él|ella|ellos|ellas|que|porque|mientras|aunque|dijo|pensé|creí)(?=\s|[.!?]|$)/iu,
  },
  {
    sourceLang: "fr",
    authorStart: /^(?:j['’]|je\b)/iu,
    recipientStart: /^tu\b/iu,
    authorMarker: /(?:\bje\b|\bj['’])/iu,
    recipientMarker: /\btu\b/iu,
    unsafe:
      /\b(?:il|elle|ils|elles|lui|leur|que|parce|pendant|quoique|dit|pensais)\b/iu,
  },
  {
    sourceLang: "uk",
    authorStart: /^я(?=\s|$)/iu,
    recipientStart: /^ти(?=\s|$)/iu,
    authorMarker: /(?:^|\s)я(?=\s|[.!?]|$)/iu,
    recipientMarker: /(?:^|\s)ти(?=\s|[.!?]|$)/iu,
    unsafe:
      /(?:^|\s)(?:він|вона|вони|його|її|їм|що|бо|коли|хоча|сказав|сказала|думав|думала)(?=\s|[.!?]|$)/iu,
  },
  {
    sourceLang: "hi",
    authorStart: /^(?:मैं|मैंने)(?:\s|$)/u,
    recipientStart: /^(?:तुम|तुमने|आप|आपने)(?:\s|$)/u,
    authorMarker: /(?:^|\s)(?:मैं|मैंने)(?:\s|$)/u,
    recipientMarker: /(?:^|\s)(?:तुम|तुमने|आप|आपने)(?:\s|$)/u,
    unsafe: /(?:^|\s)(?:वह|वे|उसने|उन्होंने|उसे|को|क्योंकि|जबकि|कि)(?:\s|$)/u,
  },
  {
    sourceLang: "nl",
    authorStart: /^ik\b/iu,
    recipientStart:
      /^(?:jij\b|je\s+(?:bent|hebt|was|had|werkt|gaat|ging|komt|kwam|kookt|maakte|deed)\b)/iu,
    authorMarker: /\bik\b/iu,
    recipientMarker:
      /(?:\bjij\b|\bje\s+(?:bent|hebt|was|had|werkt|gaat|ging|komt|kwam|kookt|maakte|deed)\b)/iu,
    unsafe:
      /\b(?:hij|zij|ze|hem|haar|hen|hun|dat|omdat|terwijl|hoewel|zei|dacht)\b/iu,
  },
  {
    sourceLang: "it",
    authorStart:
      /^(?:io\b|ho\b|ero\b|avevo\b|vado\b|andrò\b|posso\b|voglio\b|sono\s+[\p{L}\p{M}]+(?:at[oa]|ut[oa]|it[oa])\b)/iu,
    recipientStart:
      /^(?:tu\b|sei\b|hai\b|eri\b|avevi\b|vai\b|andrai\b|puoi\b|vuoi\b)/iu,
    authorMarker:
      /(?:\b(?:io|ho|ero|avevo|vado|andrò|posso|voglio)\b|\bsono\s+[\p{L}\p{M}]+(?:at[oa]|ut[oa]|it[oa])\b)/iu,
    recipientMarker: /\b(?:tu|sei|hai|eri|avevi|vai|andrai|puoi|vuoi)\b/iu,
    unsafe:
      /\b(?:lui|lei|loro|gli|che|perché|mentre|sebbene|detto|pensavo)\b/iu,
  },
  {
    sourceLang: "pt",
    authorStart:
      /^(?:eu|estou|sou|fui|tenho|tive|vou|posso|quero|cheguei)(?=\s|[.!?]|$)/iu,
    recipientStart:
      /^(?:você|tu|estás|és|foste|tens|tiveste|vais|podes|queres|chegaste)(?=\s|[.!?]|$)/iu,
    authorMarker:
      /(?:^|\s)(?:eu|estou|sou|fui|tenho|tive|vou|posso|quero)(?=\s|[.!?]|$)/iu,
    recipientMarker:
      /(?:^|\s)(?:você|tu|estás|és|foste|tens|tiveste|vais|podes|queres|chegaste)(?=\s|[.!?]|$)/iu,
    unsafe:
      /\b(?:ele|ela|eles|elas|lhe|que|porque|enquanto|embora|disse|pensei)\b/iu,
  },
  {
    sourceLang: "ta",
    authorStart:
      /^(?:நான்(?:\s|$)|.+(?:கிறேன்|கின்றேன்|த்தேன்|ட்டேன்|ந்தேன்|ன்றேன்|ப்பேன்)(?:[.!?]|$))/u,
    recipientStart:
      /^(?:நீ(?:\s|$)|நீங்கள்(?:\s|$)|.+(?:கிறாய்|கின்றாய்|த்தாய்|ட்டாய்|ந்தாய்|ன்றாய்|ப்பாய்)(?:[.!?]|$))/u,
    authorMarker:
      /(?:^|\s)நான்(?:\s|$)|(?:கிறேன்|கின்றேன்|த்தேன்|ட்டேன்|ந்தேன்|ன்றேன்|ப்பேன்)(?:[.!?]|$)/u,
    recipientMarker:
      /(?:^|\s)(?:நீ|நீங்கள்)(?:\s|$)|(?:கிறாய்|கின்றாய்|த்தாய்|ட்டாய்|ந்தாய்|ன்றாய்|ப்பாய்)(?:[.!?]|$)/u,
    unsafe:
      /(?:^|\s)(?:அவன்|அவள்|அவர்கள்|அவனை|அவளை|அதை|என்று|ஏனெனில்)(?:\s|$)|(?:^|\s)[^\s]+ை(?=\s|[.!?]|$)/u,
  },
  {
    sourceLang: "tr",
    authorStart:
      /^(?:ben(?:\s|$)|(?:.*\s)?[\p{L}\p{M}]*(?:[dt][ıiuü]m|[ıiuü]yorum|[ıiuü]m)(?:[.!?]|$))/iu,
    recipientStart:
      /^(?:sen(?:\s|$)|(?:.*\s)?[\p{L}\p{M}]*(?:[dt][ıiuü]n|[ıiuü]yorsun|s[ıiuü]n)(?:[.!?]|$))/iu,
    authorMarker:
      /(?:^|\s)(?:ben|[\p{L}\p{M}]*[dt][ıiuü]m|[\p{L}\p{M}]*[ıiuü]yorum|[\p{L}\p{M}]+[ıiuü]m)(?=\s|[.!?]|$)/iu,
    recipientMarker:
      /(?:^|\s)(?:sen|[\p{L}\p{M}]*[dt][ıiuü]n|[\p{L}\p{M}]*[ıiuü]yorsun|[\p{L}\p{M}]+s[ıiuü]n)(?=\s|[.!?]|$)/iu,
    unsafe: /\b(?:o|onlar|onu|ona|çünkü|iken|rağmen|dedi|düşündüm)\b/iu,
  },
];

function hasLikelyNamedPerson(input: string): boolean {
  const words = input.match(/[\p{L}\p{M}]+/gu) ?? [];
  return words.slice(1).some((word) => word !== "I" && /^\p{Lu}/u.test(word));
}

function containsParticipantName(
  input: string,
  participantNames: readonly string[],
): boolean {
  const words = (
    value: string,
  ) => (value.normalize("NFC").toLocaleLowerCase().match(/[\p{L}\p{M}]+/gu) ??
    []);
  const sourceWords = words(input);
  return participantNames.some((name) => {
    const nameWords = words(name);
    if (nameWords.length === 0 || nameWords.length > sourceWords.length) {
      return false;
    }
    return sourceWords.some((_, start) =>
      nameWords.every((word, offset) => sourceWords[start + offset] === word)
    );
  });
}

// US-042: conservative, unquoted, single-subject launch-language clauses are
// deterministic. Named, embedded, quoted, and mixed-person clauses stay with
// the agreement audit instead of being guessed from a pronoun occurrence.
export function directSubjectRole(
  text: string,
  sourceLang: string,
  participantNames: readonly string[] = [],
): "author" | "recipient" | null {
  const rule = DIRECT_SUBJECT_RULES.find((candidate) =>
    candidate.sourceLang === sourceLang
  );
  if (rule === undefined) return null;
  const input = text.trim().normalize("NFC").replace(/^[¿¡]\s*/u, "");
  if (
    input === "" || /["“”«»„‟\n\r;:,]/u.test(input) ||
    /^['‘’]|['‘’][.!?]?$/u.test(input) ||
    containsParticipantName(input, participantNames) ||
    sourceLang !== "de" && hasLikelyNamedPerson(input)
  ) return null;

  const author = rule.authorStart.test(input);
  const recipient = rule.recipientStart.test(input);
  if (
    !author && !recipient || author && recipient || rule.unsafe.test(input) ||
    rule.authorMarker.test(input) && rule.recipientMarker.test(input)
  ) return null;
  return author ? "author" : "recipient";
}

export function normalizeFormSubject(
  a: FormAlternatives,
  context: FormParticipantContext,
  source: string,
  sourceLang: string,
): FormAlternatives {
  const role = directSubjectRole(source, sourceLang, [
    context.viewerName,
    context.partnerName,
  ]) ??
    (a.subjectIsViewer === (context.messageAuthor === "viewer")
      ? "author"
      : "recipient");
  const viewer = role === "author"
    ? context.messageAuthor === "viewer"
    : context.messageAuthor !== "viewer";
  const subjectName = viewer ? context.viewerName : context.partnerName;
  return {
    ...a,
    subjectRole: role,
    subjectIsViewer: viewer,
    subjectName,
    suggestedForm: a.suggestedForm === "masculine" ? "masculine" : "feminine",
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
/// gendered target. A second, explicit audit may confirm that the sentence is
/// naturally form-neutral without consulting private saved preferences.
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
  suggestedForm: "feminine" | "masculine" | null;
  feminineTokens: TranslationToken[] | null;
  masculineTokens: TranslationToken[] | null;
};

function validatedCompleteTokens(
  value: unknown,
  expectedText: string,
): TranslationToken[] | null {
  if (!Array.isArray(value) || value.length === 0) return null;
  const tokens: TranslationToken[] = [];
  let reproduced = "";
  for (const raw of value) {
    if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
      return null;
    }
    const token = raw as Record<string, unknown>;
    if (
      typeof token.text !== "string" || token.text.length === 0 ||
      typeof token.isContent !== "boolean" ||
      token.gloss !== null && typeof token.gloss !== "string" ||
      token.roman !== null && typeof token.roman !== "string"
    ) return null;
    if (token.isContent) {
      const gloss = typeof token.gloss === "string" ? token.gloss.trim() : "";
      const glossWords = gloss.match(/[\p{L}\p{M}\p{N}'’]+/gu) ?? [];
      if (
        token.text.trim().length === 0 || /\s/u.test(token.text.trim()) ||
        glossWords.length < 1 || glossWords.length > 3
      ) return null;
      const hasNonLatinLetter = Array.from(token.text).some((character) =>
        /\p{L}/u.test(character) && !/\p{Script=Latin}/u.test(character)
      );
      if (hasNonLatinLetter) {
        const roman = typeof token.roman === "string" ? token.roman.trim() : "";
        const romanLetters = Array.from(roman).filter((character) =>
          /\p{L}/u.test(character)
        );
        if (
          romanLetters.length === 0 ||
          romanLetters.some((character) => !/\p{Script=Latin}/u.test(character))
        ) return null;
      }
    } else if (token.gloss !== null || token.roman !== null) {
      return null;
    }
    const parsed: TranslationToken = {
      text: token.text,
      gloss: token.gloss as string | null,
      roman: token.roman as string | null,
      isContent: token.isContent,
    };
    reproduced += parsed.text;
    tokens.push(parsed);
  }
  return reproduced === expectedText ? tokens : null;
}

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
    value.after !== null && typeof value.after !== "string" ||
    value.suggestedForm !== null && value.suggestedForm !== "feminine" &&
      value.suggestedForm !== "masculine"
  ) return null;
  if (value.requiresChoice) {
    if (
      typeof value.subjectIsViewer !== "boolean" ||
      typeof value.before !== "string" ||
      typeof value.feminine !== "string" || value.feminine.trim() === "" ||
      typeof value.masculine !== "string" || value.masculine.trim() === "" ||
      typeof value.after !== "string" ||
      value.feminine === value.masculine ||
      value.suggestedForm !== "feminine" && value.suggestedForm !== "masculine"
    ) return null;
    const feminineSentence = `${value.before}${value.feminine}${value.after}`;
    const masculineSentence = `${value.before}${value.masculine}${value.after}`;
    const feminineTokens = validatedCompleteTokens(
      value.feminineTokens,
      feminineSentence,
    );
    const masculineTokens = validatedCompleteTokens(
      value.masculineTokens,
      masculineSentence,
    );
    if (feminineTokens === null || masculineTokens === null) return null;
    return {
      requiresChoice: true,
      subjectIsViewer: value.subjectIsViewer,
      before: value.before,
      feminine: value.feminine,
      masculine: value.masculine,
      after: value.after,
      suggestedForm: value.suggestedForm,
      feminineTokens,
      masculineTokens,
    };
  } else if (
    value.subjectIsViewer !== null || value.before !== null ||
    value.feminine !== null || value.masculine !== null ||
    value.after !== null ||
    value.suggestedForm !== null || value.feminineTokens !== null ||
    value.masculineTokens !== null
  ) {
    return null;
  }
  return {
    requiresChoice: false,
    subjectIsViewer: null,
    before: null,
    feminine: null,
    masculine: null,
    after: null,
    suggestedForm: null,
    feminineTokens: null,
    masculineTokens: null,
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
    alternatives.after === audit.after &&
    JSON.stringify(alternatives.feminineTokens) ===
      JSON.stringify(audit.feminineTokens) &&
    JSON.stringify(alternatives.masculineTokens) ===
      JSON.stringify(audit.masculineTokens);
}

export function formAlternativesFromConfirmedAudit(
  result: TranslationResult,
  audit: FormAuditResult,
  formContext: FormParticipantContext,
): FormAlternatives | null {
  const feminineSentence = typeof audit.before === "string" &&
      typeof audit.feminine === "string" && typeof audit.after === "string"
    ? `${audit.before}${audit.feminine}${audit.after}`
    : null;
  const masculineSentence = typeof audit.before === "string" &&
      typeof audit.masculine === "string" && typeof audit.after === "string"
    ? `${audit.before}${audit.masculine}${audit.after}`
    : null;
  const feminineTokens = feminineSentence === null
    ? null
    : validatedCompleteTokens(audit.feminineTokens, feminineSentence);
  const masculineTokens = masculineSentence === null
    ? null
    : validatedCompleteTokens(audit.masculineTokens, masculineSentence);
  if (
    result.mode !== "translation" || !audit.requiresChoice ||
    typeof audit.subjectIsViewer !== "boolean" ||
    typeof audit.before !== "string" ||
    typeof audit.feminine !== "string" ||
    typeof audit.masculine !== "string" ||
    typeof audit.after !== "string" ||
    feminineTokens === null || masculineTokens === null ||
    feminineSentence !== result.translation
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
    feminineTokens,
    masculineTokens,
  };
}

export function applyConfirmedFormAudit(
  result: TranslationResult,
  audit: FormAuditResult,
  formContext: FormParticipantContext,
): TranslationResult | null {
  if (
    !audit.requiresChoice || typeof audit.before !== "string" ||
    typeof audit.feminine !== "string" || typeof audit.after !== "string"
  ) return null;
  const candidate: TranslationResult = {
    ...result,
    translation: `${audit.before}${audit.feminine}${audit.after}`,
    tokens: audit.feminineTokens ?? [],
    formAlternatives: null,
  };
  const alternatives = formAlternativesFromConfirmedAudit(
    candidate,
    audit,
    formContext,
  );
  return alternatives === null
    ? null
    : { ...candidate, formAlternatives: alternatives };
}

export function formAuditSystemPrompt(
  sourceLang: string,
  targetLang: string,
  interfaceLang: string,
  formContext: FormParticipantContext,
): string {
  const sourceName = LANG_NAMES[sourceLang] ?? sourceLang;
  const targetName = LANG_NAMES[targetLang] ?? targetLang;
  const interfaceName = LANG_NAMES[interfaceLang] ?? interfaceLang;
  return `You verify grammatical agreement in one translated chat message.
The source language is ${sourceName} (${sourceLang}); the target is ${targetName} (${targetLang}).
The interface language is ${interfaceName} (${interfaceLang}).
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
Decide whether the shortest complete natural target-language sentence changes between feminine and masculine for the viewer or partner. Check verbs, adjectives, participles, pronouns, agreement, and gendered person nouns together. Do not treat masculine as a generic default. Do not avoid a real choice with an awkward neutral rewrite. For suggestedForm use the affected person’s supplied name; when unclear use feminine. For example, Alice suggests feminine, Bob suggests masculine, and an ambiguous Alex defaults to feminine. Saved preferences are private client state and must not affect this shared result. Do not change the sentence to avoid a form choice and do not infer from topic or writing style.

Return strict JSON only: {"requiresChoice":true|false,"subjectIsViewer":true|false|null,"before":"shared prefix"|null,"feminine":"shortest complete feminine fragment"|null,"masculine":"shortest complete masculine fragment"|null,"after":"shared suffix"|null,"suggestedForm":"feminine"|"masculine"|null,"feminineTokens":[{"text":"segment","gloss":"1-3 word ${interfaceName} gloss","roman":"Latin transliteration","isContent":true}]|null,"masculineTokens":[{"text":"segment","gloss":"1-3 word ${interfaceName} gloss","roman":"Latin transliteration","isContent":true}]|null}.
When a natural choice is required, identify the affected participant and split the target sentence around the shortest complete fragment containing every linked agreement change. Keep all identical text in before/after. For a single changing verb such as “Ти ходила/ходив до…”, return before="Ти ", feminine="ходила", masculine="ходив", and after=" до…"—never repeat the whole sentence in either option. feminineTokens and masculineTokens must each reproduce the corresponding complete sentence exactly, including the shared before/after text. Every content token is one word with a short 1-3 word ${interfaceName} gloss. Every non-Latin content token also has a non-empty Latin-script romanization. Whitespace and punctuation tokens have null gloss and roman. When no choice is required, the participant, suggestion, all four text fields, and both token arrays must be null.`;
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

const SHORT_SOURCE_RETRY_MAX_CHARS = 24;
const SHORT_PLAIN_SOURCE = /^[\p{L}\p{M}][\p{L}\p{M}\s'’-]*$/u;

function canRetrySourceClassification(text: string): boolean {
  const value = text.trim();
  return value.length > 0 &&
    value.length <= SHORT_SOURCE_RETRY_MAX_CHARS &&
    SHORT_PLAIN_SOURCE.test(value);
}

const SUPPORTED_CHAT_ABBREVIATIONS = new Set([
  "omg",
  "ttyl",
  "brb",
  "lol",
  "lmao",
  "idk",
  "fyi",
  "wtf",
]);

function scriptCompatibleWithLanguage(text: string, language: string): boolean {
  const letters = Array.from(text).filter((character) =>
    /\p{L}/u.test(character)
  );
  if (letters.length === 0) return false;
  const pattern = language === "uk"
    ? /\p{Script=Cyrillic}/u
    : language === "hi"
    ? /\p{Script=Devanagari}/u
    : language === "ta"
    ? /\p{Script=Tamil}/u
    : /\p{Script=Latin}/u;
  return letters.every((character) => pattern.test(character));
}

const SUPPORTED_SOURCE_SCRIPTS =
  /[\p{Script=Latin}\p{Script=Cyrillic}\p{Script=Devanagari}\p{Script=Tamil}]/u;

/// Returns true when authored text contains a letter from a script that none
/// of Blab's supported languages use. This lets obvious unsupported text keep
/// its original without depending on probabilistic provider classification.
export function unsupportedSourceScript(text: string): boolean {
  return Array.from(text).some((character) =>
    /\p{L}/u.test(character) && !SUPPORTED_SOURCE_SCRIPTS.test(character)
  );
}

function supportedAbbreviationText(text: string): boolean {
  const words = text.match(/[\p{L}\p{M}]+(?:['’-][\p{L}\p{M}]+)*/gu) ?? [];
  if (
    !words.some((word) =>
      SUPPORTED_CHAT_ABBREVIATIONS.has(word.toLocaleLowerCase())
    )
  ) return false;
  return words.every((word) =>
    SUPPORTED_CHAT_ABBREVIATIONS.has(word.toLocaleLowerCase()) ||
    /^[\p{Script=Latin}\p{M}]+(?:['’-][\p{Script=Latin}\p{M}]+)*$/u.test(word)
  );
}

export function recognizedAbbreviationSourceLanguage(
  text: string,
): string | null {
  return supportedAbbreviationText(text) ? "en" : null;
}

/// Rejects only provider source labels contradicted by bounded, private
/// evidence already attached to this translation job. The existing provider
/// loop owns the single retry; this predicate never performs extra work.
export function sourceEvidenceNeedsRetry({
  result,
  sourceText,
  targetLang,
  context = [],
  formContext,
}: {
  result: TranslationResult;
  sourceText: string;
  targetLang: string;
  context?: TranslationContextMessage[];
  formContext?: FormParticipantContext;
}): boolean {
  if (
    result.sourceLang === OTHER_SOURCE_LANG &&
    supportedAbbreviationText(sourceText)
  ) return true;

  if (
    result.sourceLang !== targetLang ||
    result.mode !== "none" ||
    result.translation.trim().toLocaleLowerCase() !==
      sourceText.trim().toLocaleLowerCase() ||
    !canRetrySourceClassification(sourceText)
  ) return false;

  if (!scriptCompatibleWithLanguage(sourceText, targetLang)) return true;

  const authorLanguage = formContext?.authorPrimaryKnownLanguage;
  if (
    authorLanguage != null &&
    authorLanguage !== targetLang &&
    scriptCompatibleWithLanguage(sourceText, authorLanguage)
  ) return true;

  if (formContext === undefined) return false;
  const sameSenderContext = context.filter((entry) =>
    entry.speaker === formContext.messageAuthor
  );
  if (
    sameSenderContext.some((entry) =>
      entry.sourceLang != null && entry.sourceLang !== targetLang
    )
  ) return true;
  return sameSenderContext.some((entry) =>
    !scriptCompatibleWithLanguage(entry.text, targetLang) &&
    scriptCompatibleWithLanguage(sourceText, authorLanguage ?? targetLang)
  );
}

/// Chooses a source language for the existing second provider attempt when
/// the first result copied the source or contradicted the bounded evidence.
/// A short ambiguous utterance uses the author's known language as the final
/// tie-breaker; otherwise a supported non-target provider label is retained.
export function sourceEvidenceLanguage({
  result,
  sourceText,
  targetLang,
  context = [],
  formContext,
}: {
  result: TranslationResult;
  sourceText: string;
  targetLang: string;
  context?: TranslationContextMessage[];
  formContext?: FormParticipantContext;
}): string | null {
  const authorLanguage = formContext?.authorPrimaryKnownLanguage;
  const contextualLanguage = formContext === undefined ? null : [...context]
    .reverse()
    .find((entry: TranslationContextMessage) =>
      entry.speaker === formContext.messageAuthor &&
      entry.sourceLang != null &&
      entry.sourceLang !== targetLang
    )?.sourceLang ?? null;
  const abbreviationLanguage = recognizedAbbreviationSourceLanguage(
    sourceText,
  );
  if (abbreviationLanguage !== null) return abbreviationLanguage;
  if (
    canRetrySourceClassification(sourceText) &&
    contextualLanguage != null &&
    scriptCompatibleWithLanguage(sourceText, contextualLanguage)
  ) return contextualLanguage;
  if (
    canRetrySourceClassification(sourceText) &&
    authorLanguage != null &&
    authorLanguage !== targetLang &&
    scriptCompatibleWithLanguage(sourceText, authorLanguage)
  ) return authorLanguage;

  return result.sourceLang !== OTHER_SOURCE_LANG &&
      result.sourceLang !== targetLang
    ? result.sourceLang
    : null;
}

export function sourceClassificationRetryGuidance(
  targetLang: string,
): string {
  const targetName = LANG_NAMES[targetLang] ?? targetLang;
  return ` The previous source-language classification conflicted with the authored text or its bounded evidence. Re-detect the original authored text independently from the target language. Treat the current message as a complete utterance even when it contains only one word, and translate that utterance's semantic meaning rather than copying its spelling. For a genuinely ambiguous short utterance, use recent messages from the same sender and then the author's primary known language as a weak final tie-breaker. A meaning-bearing chat abbreviation combined with compatible Latin-script words or names remains supported language. If the source is not truly ${targetName} (${targetLang}), use mode=translation and return the complete ${targetName} translation.`;
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
  if (result.sourceClassificationConflict === true) return true;
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
  resolvedSourceLang?: string,
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

  const sourceLang = resolvedSourceLang ?? normalizeSourceLang(raw.sourceLang);
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
    if (canRetrySourceClassification(text)) {
      result.sourceClassificationConflict = true;
    }
    result.mode = "none";
    result.translation = text;
    result.interfaceText = interfaceLang === targetLang ? text : "";
    result.explanation = null;
    result.confidence = null;
    result.tokens = [];
  }
  // Duplicate target/interface lanes are fully determined by the learning
  // translation. A distinct source/interface lane may contain a provider's
  // clean correction, with the authored text retained as its safe fallback.
  if (interfaceLang === targetLang) {
    result.interfaceText = result.translation;
  } else if (
    sourceLang === interfaceLang && result.interfaceText.trim().length === 0
  ) {
    // Keep a provider correction in the reader's interface language. Falling
    // back to the authored line is only necessary when that lane is missing;
    // otherwise clear source mistakes would leak into the main chat display.
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
  const feminineTokens = validatedCompleteTokens(
    raw.feminineTokens,
    `${raw.before}${raw.feminine}${raw.after}`,
  );
  const masculineTokens = validatedCompleteTokens(
    raw.masculineTokens,
    `${raw.before}${raw.masculine}${raw.after}`,
  );
  if (feminineTokens === null || masculineTokens === null) return null;
  return {
    before: raw.before,
    feminine: raw.feminine,
    masculine: raw.masculine,
    after: raw.after,
    subjectName: raw.subjectName,
    subjectIsViewer: raw.subjectIsViewer,
    suggestedForm: raw.suggestedForm === "masculine" ? "masculine" : "feminine",
    feminineTokens,
    masculineTokens,
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
    : `Participants: viewer=${formContext.viewerName}; partner=${formContext.partnerName}; current message author=${formContext.messageAuthor}; chat tone=${formContext.tone}. For a direct first/second-person message, "I" normally refers to the author and "you" to the other participant. Saved grammatical-form choices are applied privately by the client and must not be inferred or encoded in this shared translation.`;
  const authorLanguageHint = formContext?.authorPrimaryKnownLanguage == null
    ? ""
    : ` The author's primary known language is ${
      LANG_NAMES[formContext.authorPrimaryKnownLanguage]
    } (${formContext.authorPrimaryKnownLanguage}); use it only as a final tie-breaker when the current text is genuinely ambiguous and compatible with that language.`;
  return `You normalize a message for a language-learning chat.

${sourceInstruction}
The viewer's learning language is ${targetName} (${targetLang}).
The viewer's interface language is ${interfaceName} (${interfaceLang}).
${formInstruction}${authorLanguageHint}

Return strict JSON only:
{
  "mode": "<translation, correction, or none>",
  "sourceLang": "<detected supported code, or ${OTHER_SOURCE_LANG}>",
  "translation": "<the complete ${targetName} learning-language line>",
  "interfaceText": "<the complete ${interfaceName} interface-language line>",
  "explanation": "<short ${interfaceName} correction explanation, or null>",
  "confidence": "<low, medium, high, or null>",
  "formAlternatives": { "before": "<unchanged prefix>", "feminine": "<complete feminine affected fragment>", "masculine": "<complete masculine affected fragment>", "after": "<unchanged suffix>", "subjectName": "<viewer or partner display name>", "subjectIsViewer": true, "suggestedForm": "feminine", "feminineTokens": [{"text":"<segment of complete feminine sentence>","gloss":"<1-3 word ${interfaceName} gloss>","roman":"<romanization>","isContent":true}], "masculineTokens": [{"text":"<segment of complete masculine sentence>","gloss":"<1-3 word ${interfaceName} gloss>","roman":"<romanization>","isContent":true}] },
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
- A meaning-bearing chat abbreviation combined with compatible Latin-script words or names remains supported language. Translate the abbreviation naturally and preserve or transliterate names; do not label the message unsupported merely because a name follows the abbreviation.
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
- Set formAlternatives to null unless the target sentence genuinely requires a feminine/masculine choice for the viewer or partner. When it is required, set translation to the feminine rendering, and concatenate before + feminine + after to reproduce translation exactly. feminine and masculine must be complete, natural alternatives for the same shortest understandable affected fragment; include every linked agreement change together. feminineTokens and masculineTokens must each reproduce their complete resolved sentence exactly, including the shared before/after text, and follow the same per-word metadata rules as tokens. subjectIsViewer identifies the affected participant and subjectName is their display name. Set suggestedForm from their name, or feminine if unclear. Never encode a saved preference in this shared translation; it never changes the identity of the affected participant.
- This is a required output rule, not a suggestion to make wording neutral. For example, ONLY when the viewer authored English "What did you do yesterday?", Ukrainian MUST return translation="Що ти робила вчора?" and formAlternatives={"before":"Що ти ","feminine":"робила","masculine":"робив","after":" вчора?","subjectName":"<partner name>","subjectIsViewer":false,"suggestedForm":"feminine","feminineTokens":[{"text":"Що","gloss":"what","roman":"Shcho","isContent":true},{"text":" ","gloss":null,"roman":null,"isContent":false},{"text":"ти","gloss":"you","roman":"ty","isContent":true},{"text":" ","gloss":null,"roman":null,"isContent":false},{"text":"робила","gloss":"did","roman":"robyla","isContent":true},{"text":" ","gloss":null,"roman":null,"isContent":false},{"text":"вчора","gloss":"yesterday","roman":"vchora","isContent":true},{"text":"?","gloss":null,"roman":null,"isContent":false}],"masculineTokens":[{"text":"Що","gloss":"what","roman":"Shcho","isContent":true},{"text":" ","gloss":null,"roman":null,"isContent":false},{"text":"ти","gloss":"you","roman":"ty","isContent":true},{"text":" ","gloss":null,"roman":null,"isContent":false},{"text":"робив","gloss":"did","roman":"robyv","isContent":true},{"text":" ","gloss":null,"roman":null,"isContent":false},{"text":"вчора","gloss":"yesterday","roman":"vchora","isContent":true},{"text":"?","gloss":null,"roman":null,"isContent":false}]}. When the partner authored that same question, subjectIsViewer MUST instead be true and subjectName MUST be the viewer’s name. Apply the same rule to the natural feminine/masculine fragment in every supported target language; French/Hindi may need a multi-word fragment.
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
