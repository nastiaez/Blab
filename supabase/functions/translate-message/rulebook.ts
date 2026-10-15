// Canonical translation policy configuration. PRD remains the product authority.
// Update this module, its behavioral tests, and regenerate docs/translation-rulebook.md.
export const MAX_CHARS = 2000;

export const OPENROUTER_PROVIDER = {
  sort: "latency",
  allow_fallbacks: true,
  require_parameters: true,
  data_collection: "deny",
  zdr: true,
} as const;

export const DEFAULT_OPENROUTER_MODEL = "google/gemini-3.1-flash-lite";

export const DEFAULT_OPENAI_MODEL = "gpt-4o-mini";

export const FRAGMENT_FIDELITY_RULE =
  "Keep short elliptical replies as fragments when the author supplied a fragment. Use explicit recent context to resolve what is being contrasted, without inventing a new assertion. For example, after a meeting time of six, Not seven excludes seven as that time; it does not assert that the current clock time is not seven. Never add now, currently, a new subject, or a new event unless the source or explicit context supports it.";

export const SEMANTIC_FIDELITY_RULE =
  "Resolve every source word's meaning in context before choosing target wording. Never choose a target word merely because its spelling resembles the source: cross-language false friends can have different meanings. Preserve ambiguous isolated characters and initials literally; never expand O to ears or another guessed noun. Before returning, mentally back-translate the complete target sentence into the source language and confirm that every content word and relationship preserves the original meaning. " +
  FRAGMENT_FIDELITY_RULE;

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

export const LATIN_TARGETS = new Set([
  "en",
  "nl",
  "fr",
  "de",
  "it",
  "pt",
  "es",
  "tr",
]);

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

export const FORM_RELEVANT_TARGET_LANGS = new Set([
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

export const SHORT_SOURCE_RETRY_MAX_CHARS = 24;

export const SHORT_PLAIN_SOURCE = /^[\p{L}\p{M}][\p{L}\p{M}\s'’-]*$/u;

export const SUPPORTED_CHAT_ABBREVIATIONS = new Set([
  "omg",
  "ttyl",
  "brb",
  "lol",
  "lmao",
  "idk",
  "fyi",
  "wtf",
]);

export const PROTECTED_CONTENT_RULE =
  "Preserve meaning and tone. Keep URLs, @mentions, hashtags, code, numbers, and emoji unchanged, and preserve names' identity rather than translating their meaning; transliterate a confidently identified name when the target script differs. Move protected content with the surrounding sentence when the target language needs a different natural word order.";
export const READABLE_PHASE_RULE =
  "\n\nReadable-text phase: obey the supplied response schema. " +
  "Generate the complete translated/corrected sentence, known-language sentence, " +
  "correction explanation and all required grammatical alternatives. " +
  "Do not generate tokens, word glosses, transliterations, feminineTokens or " +
  "masculineTokens in this phase. A separate background job prepares word help " +
  "from the accepted final text. Never omit a meaning, correction or required " +
  "grammatical choice merely because its word metadata is deferred.";

export const ACKNOWLEDGEMENT = {
  words: ["ok", "okay"],
  terminalPunctuation: [".", "!", "?", "…"],
} as const;

export function isStandaloneAcknowledgement(text: string): boolean {
  const characters = Array.from(text.trim().toLowerCase());
  while (
    characters.length &&
    (ACKNOWLEDGEMENT.terminalPunctuation as readonly string[]).includes(
      characters.at(-1)!,
    )
  ) characters.pop();
  return (ACKNOWLEDGEMENT.words as readonly string[]).includes(
    characters.join(""),
  );
}

export function acknowledgementPromptRule(): string {
  return `For a whole-message acknowledgement (${
    ACKNOWLEDGEMENT.words.join(" / ")
  }, case-insensitive, optionally ending with ${
    ACKNOWLEDGEMENT.terminalPunctuation.join(" ")
  }), unchanged spelling is not by itself a translation failure. Accept it only when valid in the requested target language with the same meaning, tone and question intent. Use natural local spelling where needed. Do not exempt sentences containing these words, other loanwords, wrong-script copies, or source-classification conflicts. Independent meaning and language validation is still required.`;
}

export const PREFERENCE_OWNERSHIP = {
  practice:
    "Viewer's applicable chat Learning Language and historical revision.",
  secondaryAndWordHelp:
    "Viewer's Primary Known Language; legacy interfaceLang parameter denotes this language, not UI language.",
  interface: "Interface Language owns UI labels only.",
  normal:
    "Known source languages retain authored text; unknown incoming text uses reader's Primary Known Language.",
  aidsOff:
    "Original text, no new AI work; preserve completed history and cache isolation.",
} as const;

export function renderTranslationRulebook(): string {
  return `# Translation rulebook

Generated from supabase/functions/translate-message/rulebook.ts. Do not edit this document directly.
Run: deno run --allow-write scripts/generate_translation_rulebook.ts
PRD remains authoritative for product behavior. This module owns the shared policy constants and prompt fragments below; validators import them directly.

## Standalone acknowledgements
${acknowledgementPromptRule()}

## Protected content
${PROTECTED_CONTENT_RULE}

## Meaning and fragments
${SEMANTIC_FIDELITY_RULE}

## Preferences (integration contract)
${
    Object.entries(PREFERENCE_OWNERSHIP).map(([key, value]) =>
      `- ${key}: ${value}`
    ).join("\n")
  }
Preference resolution remains in client/worker code, not a second resolver here.

## Languages and classifications
- Supported learning languages: ${JSON.stringify(LANG_NAMES)}
- UI languages: ${[...INTERFACE_LANGS].join(", ")}
- Latin targets: ${[...LATIN_TARGETS].join(", ")}
- Form-audited targets: ${[...FORM_RELEVANT_TARGET_LANGS].join(", ")}
- Modes: ${[...LEARNING_AID_MODES].join(", ")}; confidence: ${
    [...CORRECTION_CONFIDENCE].join(", ")
  }; unsupported source: ${OTHER_SOURCE_LANG}.
- Recognized English chat abbreviations: ${
    [...SUPPORTED_CHAT_ABBREVIATIONS].join(", ")
  }. Translate meaning, not expanded English sounds.

## Grammatical forms
${GENDER_ADDRESS_RULES}

## Delivery phases
${READABLE_PHASE_RULE.trim()}

## Limits and provider defaults
- Message limit: ${MAX_CHARS} characters.
- Focused source retry eligibility: ${SHORT_SOURCE_RETRY_MAX_CHARS} characters; pattern: ${SHORT_PLAIN_SOURCE}.
- Default OpenRouter model: ${DEFAULT_OPENROUTER_MODEL}; OpenAI fallback model: ${DEFAULT_OPENAI_MODEL}. Existing environment overrides still apply.
- OpenRouter routing: ${JSON.stringify(OPENROUTER_PROVIDER)}.

## Other configuration owners
This is the policy entry point, not a claim that all app settings live here:
- contract.ts: schemas, literal recognition, script validation and semantic predicates.
- index.ts: ordered audits, provider deadlines and worker orchestration; acknowledgement acceptance follows independent audits.
- readable_delivery.ts: accepted-sentence/word-help separation and known-language copy repair.
- ../prepare-message-jobs: per-viewer language/revision job preparation.
- Database migrations: durable retry scheduling and job attempt budgets.
- tasks/prd-blab.md: Normal/Practice, aids-off, historical and correction eligibility requirements.
Do not duplicate policy values in new prompts or validators. Move any newly configurable policy here and generate this reference in the same change.
`;
}
