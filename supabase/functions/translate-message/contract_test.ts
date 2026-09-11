import {
  characterCount,
  correctionNeedsRetry,
  genderedAmbiguityNeedsRetry,
  INTERFACE_RESPONSE_FORMAT,
  interfaceOutputNeedsRetry,
  interfaceRepairSystemPrompt,
  MAX_CHARS,
  OPENROUTER_PROVIDER,
  parseProviderResult,
  providerCredentials,
  providerMessages,
  providerResultFailureReason,
  systemPrompt,
  TRANSLATION_RESPONSE_FORMAT,
  translationNeedsRetry,
  validateRequest,
} from "./contract.ts";
import * as contract from "./contract.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

Deno.test("counts user-perceived characters", () => {
  assert(characterCount("a") === 1, "ASCII character count");
  assert(characterCount("👨‍👩‍👧‍👦") === 1, "joined emoji character count");
});

Deno.test("rejects a same-language correction that drops caption content", () => {
  const base = {
    mode: "correction" as const,
    sourceLang: "en",
    interfaceText: "I'm in a cafe. Jealous?",
    explanation: "Corrected spelling.",
    confidence: "high" as const,
    tokens: [],
    formAlternatives: null,
  };
  assert(
    correctionNeedsRetry({
      ...base,
      translation: "Are you jealous?",
    }, "I'm in a cafe. Jealouse?"),
    "dropped caption sentence must retry",
  );
  assert(
    !correctionNeedsRetry({
      ...base,
      translation: "I'm in a cafe. Jealous?",
    }, "I'm in a cafe. Jealouse?"),
    "complete spelling correction should pass",
  );
});

Deno.test("accepts only a message UUID", () => {
  const accepted = validateRequest({
    messageId: "10000000-0000-4000-8000-000000000001",
  });
  assert("request" in accepted, "message UUID should pass");

  const rejected = validateRequest({
    messageId: "not-a-message-id",
  });
  assert(
    "error" in rejected && rejected.error === "invalid_message_id",
    "invalid ID should fail",
  );
});

Deno.test("provider route permits every eligible ZDR endpoint", () => {
  assert(!("only" in OPENROUTER_PROVIDER), "provider is not pinned");
  assert(OPENROUTER_PROVIDER.allow_fallbacks, "fallbacks allowed");
  assert(OPENROUTER_PROVIDER.zdr, "ZDR required");
  assert(OPENROUTER_PROVIDER.data_collection === "deny", "collection denied");
  assert(OPENROUTER_PROVIDER.require_parameters, "parameters required");
});

Deno.test("provider credentials prefer OpenRouter and fall back to OpenAI", () => {
  const both = providerCredentials({
    openRouterKey: "router-key",
    openAiKey: "openai-key",
  });
  assert(both.length === 2, "both providers are available");
  assert(both[0].provider === "openrouter", "OpenRouter remains first");
  assert(
    both[0].model === "openai/gpt-4o-mini",
    "OpenRouter uses the production model by default",
  );
  assert(
    both[0].useOpenRouterProviderPolicy,
    "OpenRouter provider policy is enabled by default",
  );
  assert(both[1].provider === "openai", "OpenAI is the fallback");
  assert(both[1].model === "gpt-4o-mini", "OpenAI uses its native model ID");

  const openAiOnly = providerCredentials({
    openRouterKey: "",
    openAiKey: "openai-key",
  });
  assert(openAiOnly.length === 1, "empty OpenRouter key is ignored");
  assert(openAiOnly[0].provider === "openai", "OpenAI can run locally alone");

  const localOverride = providerCredentials({
    openRouterKey: "router-key",
    openRouterModel: "openai/gpt-oss-20b:free",
    openRouterProviderPolicy: "false",
    environment: "local",
  });
  assert(
    localOverride[0].model === "openai/gpt-oss-20b:free",
    "local OpenRouter model can be overridden",
  );
  assert(
    !localOverride[0].useOpenRouterProviderPolicy,
    "local OpenRouter provider policy can be disabled",
  );

  const hostedOverrideIgnored = providerCredentials({
    openRouterKey: "router-key",
    openRouterProviderPolicy: "false",
    environment: "production",
  });
  assert(
    hostedOverrideIgnored[0].useOpenRouterProviderPolicy,
    "hosted environments keep the OpenRouter provider policy",
  );
});

Deno.test("provider messages include recent context but translate only current text", () => {
  const messages = providerMessages({
    sourceLang: "auto",
    targetLang: "en",
    interfaceLang: "uk",
    text: "Їде 01.08",
    context: [
      { speaker: "viewer", text: "О то вона ще не їде до тебе?" },
      { speaker: "viewer", text: "Я думала вона 30-го десь назад" },
    ],
  });

  assert(messages.length === 2, "context is folded into system prompt");
  assert(
    messages[0].content.includes("Recent chat context"),
    "system prompt should include context",
  );
  assert(
    messages[0].content.includes("Use context only"),
    "context must not become translation input",
  );
  assert(
    messages[0].content.includes("viewer: О то вона ще не їде до тебе?"),
    "previous chat lines should be available",
  );
  assert(
    messages[1].content === "Їде 01.08",
    "current provider user message remains only the text to translate",
  );
});

Deno.test("provider uses saved form then name suggestion then feminine without rewriting", () => {
  const prompt = systemPrompt("auto", "uk", "de");
  assert(
    prompt.includes("Use an explicit saved grammatical form first"),
    "saved form wins",
  );
  assert(
    prompt.includes("use feminine if the name is ambiguous"),
    "ambiguous names use feminine",
  );
  assert(
    prompt.includes("Do not replace them with an awkward neutral rewrite"),
    "keep the sentence",
  );
  assert(prompt.includes("Preserve authored formality"), "preserve address");
});

Deno.test("English to Ukrainian rejects parenthetical gender alternatives", () => {
  const gendered = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "en",
      translation: "Я був(ла) радий(а) бачити тебе.",
      interfaceText: "Я був(ла) радий(а) бачити тебе.",
      explanation: null,
      confidence: null,
      tokens: [],
    }),
    "I was glad to see you.",
    "uk",
    "uk",
  );
  assert(gendered !== null, "provider output is structurally valid");
  assert(
    genderedAmbiguityNeedsRetry(gendered!, "en", "uk"),
    "parenthetical masculine/feminine Ukrainian forms must be retried",
  );

  const masculineDefault = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "en",
      translation: "Я твій друг.",
      interfaceText: "Я твій друг.",
      explanation: null,
      confidence: null,
      tokens: [],
    }),
    "I am your friend.",
    "uk",
    "uk",
  );
  assert(
    masculineDefault !== null,
    "plain masculine default output is structurally valid",
  );
  assert(
    genderedAmbiguityNeedsRetry(masculineDefault!, "en", "uk"),
    "unsupported masculine Ukrainian defaults must be retried",
  );

  const neutral = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "en",
      translation: "Мені було приємно побачитись з тобою.",
      interfaceText: "Мені було приємно побачитись з тобою.",
      explanation: null,
      confidence: null,
      tokens: [],
    }),
    "I was glad to see you.",
    "uk",
    "uk",
  );
  assert(neutral !== null, "neutral output is structurally valid");
  assert(
    !genderedAmbiguityNeedsRetry(neutral!, "en", "uk"),
    "impersonal Ukrainian wording should pass",
  );

  assert(
    systemPrompt("auto", "uk", "uk").includes(
      "never use parentheses or slash alternatives in translation",
    ),
    "prompt must explicitly reject both-gender workaround forms",
  );
});

Deno.test("unresolved form forces one explicit audit before accepting a translation without alternatives", () => {
  const candidate = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "en",
      translation: "Ти ходив до супермаркету вчора?",
      interfaceText: "Did you go to the supermarket yesterday?",
      explanation: null,
      confidence: null,
      tokens: [],
      formAlternatives: null,
    }),
    "Did you go to the supermarket yesterday?",
    "uk",
    "en",
  );
  assert(candidate !== null, "provider output is structurally valid");

  const needsAudit = (contract as unknown as {
    missingFormAlternativesNeedsAudit?: (
      result: NonNullable<typeof candidate>,
      targetLang: string,
      formContext: {
        viewerName: string;
        partnerName: string;
        messageAuthor: "viewer" | "partner";
        viewerForm: "feminine" | "masculine" | null;
        partnerForm: "feminine" | "masculine" | null;
        tone: "informal" | "respectful";
      },
      attempt: number,
    ) => boolean;
  }).missingFormAlternativesNeedsAudit;
  assert(
    typeof needsAudit === "function",
    "translations with unresolved participant forms need an explicit audit",
  );

  const formContext = {
    viewerName: "Alice",
    partnerName: "Bob",
    messageAuthor: "viewer" as const,
    viewerForm: null,
    partnerForm: null,
    tone: "informal" as const,
  };
  assert(
    needsAudit!(candidate!, "uk", formContext, 0),
    "the first masculine-only result must be audited",
  );
  assert(
    needsAudit!(candidate!, "uk", formContext, 1),
    "a retried candidate also needs ownership validation within the bounded attempt loop",
  );
  assert(
    !needsAudit!(candidate!, "en", formContext, 0),
    "languages with natural gender-neutral wording do not need an audit",
  );
  assert(
    needsAudit!(
      candidate!,
      "uk",
      { ...formContext, viewerForm: "feminine", partnerForm: "masculine" },
      0,
    ),
    "saved forms still need alternatives so the annotated message can be corrected",
  );
});

Deno.test("focused grammatical-form audit requires a participant when a choice is needed", () => {
  const parseAudit = (contract as unknown as {
    parseFormAuditResult?: (content: string) => {
      requiresChoice: boolean;
      subjectIsViewer: boolean | null;
      before: string | null;
      feminine: string | null;
      masculine: string | null;
      after: string | null;
    } | null;
  }).parseFormAuditResult;
  assert(
    typeof parseAudit === "function",
    "the focused grammatical-form audit response must be validated",
  );

  const required = parseAudit!(
    '{"requiresChoice":true,"subjectIsViewer":false,"before":"Ти ","feminine":"ходила","masculine":"ходив","after":" до супермаркету вчора?"}',
  );
  assert(
    required?.requiresChoice === true &&
      required.subjectIsViewer === false &&
      required.before === "Ти " && required.feminine === "ходила" &&
      required.masculine === "ходив" &&
      required.after === " до супермаркету вчора?",
    "a required partner form retains only the shortest changing fragment",
  );
  assert(
    parseAudit!(
      '{"requiresChoice":true,"subjectIsViewer":false,"before":null,"feminine":null,"masculine":null,"after":null}',
    ) === null,
    "a required choice without both exact fragments is rejected",
  );

  const neutral = parseAudit!(
    '{"requiresChoice":false,"subjectIsViewer":null,"before":null,"feminine":null,"masculine":null,"after":null}',
  );
  assert(
    neutral?.requiresChoice === false && neutral.subjectIsViewer === null &&
      neutral.before === null && neutral.feminine === null &&
      neutral.masculine === null && neutral.after === null,
    "a genuinely form-neutral sentence is accepted",
  );
});

Deno.test("confirmed alternatives must keep the audit's minimal changing fragment", () => {
  const matchesAudit = (contract as unknown as {
    confirmedFormAlternativesMatchAudit?: (
      alternatives: {
        before: string;
        feminine: string;
        masculine: string;
        after: string;
        subjectName: string;
        subjectIsViewer: boolean;
      } | null,
      audit: {
        requiresChoice: boolean;
        subjectIsViewer: boolean | null;
        before: string | null;
        feminine: string | null;
        masculine: string | null;
        after: string | null;
      },
    ) => boolean;
  }).confirmedFormAlternativesMatchAudit;
  assert(
    typeof matchesAudit === "function",
    "confirmed alternatives must be checked against the focused audit",
  );
  const audit = {
    requiresChoice: true,
    subjectIsViewer: false,
    before: "Ти ",
    feminine: "ходила",
    masculine: "ходив",
    after: " до супермаркету вчора?",
  };
  assert(
    matchesAudit!(
      {
        ...audit,
        subjectName: "Bob",
        subjectIsViewer: false,
        before: "Ти ",
        feminine: "ходила",
        masculine: "ходив",
        after: " до супермаркету вчора?",
      },
      audit,
    ),
    "the minimal verb alternatives match",
  );
  assert(
    !matchesAudit!(
      {
        before: "",
        feminine: "Ти ходила до супермаркету вчора?",
        masculine: "Ти ходив до супермаркету вчора?",
        after: "",
        subjectName: "Bob",
        subjectIsViewer: false,
      },
      audit,
    ),
    "whole-sentence options must be rejected",
  );
});

Deno.test("focused audit can attach minimal alternatives to its exact feminine translation", () => {
  const alternativesFromAudit = (contract as unknown as {
    formAlternativesFromConfirmedAudit?: (
      result: {
        mode: "translation" | "correction" | "none";
        sourceLang: string;
        translation: string;
        interfaceText: string;
        explanation: string | null;
        confidence: "low" | "medium" | "high" | null;
        tokens: unknown[];
        formAlternatives: null;
      },
      audit: {
        requiresChoice: boolean;
        subjectIsViewer: boolean | null;
        before: string | null;
        feminine: string | null;
        masculine: string | null;
        after: string | null;
      },
      formContext: {
        viewerName: string;
        partnerName: string;
        messageAuthor: "viewer" | "partner";
        viewerForm: "feminine" | "masculine" | null;
        partnerForm: "feminine" | "masculine" | null;
        tone: "informal" | "respectful";
      },
    ) => {
      before: string;
      feminine: string;
      masculine: string;
      after: string;
      subjectName: string;
      subjectIsViewer: boolean;
    } | null;
  }).formAlternativesFromConfirmedAudit;
  assert(
    typeof alternativesFromAudit === "function",
    "a confirmed audit must be able to supply omitted alternatives",
  );
  const audit = {
    requiresChoice: true,
    subjectIsViewer: false,
    before: "Ти ",
    feminine: "ходила",
    masculine: "ходив",
    after: " до супермаркету вчора?",
  };
  const result = {
    mode: "translation" as const,
    sourceLang: "en",
    translation: "Ти ходила до супермаркету вчора?",
    interfaceText: "Did you go to the supermarket yesterday?",
    explanation: null,
    confidence: null,
    tokens: [],
    formAlternatives: null,
  };
  const formContext = {
    viewerName: "Alice",
    partnerName: "Bob",
    messageAuthor: "viewer" as const,
    viewerForm: null,
    partnerForm: null,
    tone: "informal" as const,
  };
  const alternatives = alternativesFromAudit!(result, audit, formContext);
  assert(
    alternatives?.before === "Ти " &&
      alternatives.feminine === "ходила" &&
      alternatives.masculine === "ходив" &&
      alternatives.after === " до супермаркету вчора?" &&
      alternatives.subjectName === "Bob" &&
      alternatives.subjectIsViewer === false,
    "the omitted provider object is rebuilt from the confirmed minimal split",
  );
  assert(
    alternativesFromAudit!(
      { ...result, translation: "Ти ходив до супермаркету вчора?" },
      audit,
      formContext,
    ) === null,
    "the audit cannot overwrite a different rendered translation",
  );
});

Deno.test("prompt distinguishes author and recipient for Ukrainian questions", () => {
  const prompt = systemPrompt("auto", "uk", "en");
  assert(
    prompt.includes("ONLY when the viewer authored"),
    "outgoing example is scoped",
  );
  assert(
    prompt.includes(
      "When the partner authored that same question, subjectIsViewer MUST instead be true",
    ),
    "incoming question names viewer",
  );
});

Deno.test("prompt preserves supplied conversation tone", () => {
  assert(
    systemPrompt("auto", "de", "en").includes(
      "use the supplied per-chat tone: informal or respectful",
    ),
    "preserve address fallback",
  );
});

Deno.test("interface repair reuses provisional form and address rules", () => {
  const prompt = interfaceRepairSystemPrompt("de", "uk");
  assert(
    prompt.includes("use feminine if the name is ambiguous"),
    "same fallback rule",
  );
  assert(prompt.includes("Preserve authored formality"), "same address rule");
});

Deno.test("provider responses use strict schemas", () => {
  assert(
    TRANSLATION_RESPONSE_FORMAT.type === "json_schema",
    "translation schema enabled",
  );
  assert(
    TRANSLATION_RESPONSE_FORMAT.json_schema.strict,
    "translation schema is strict",
  );
  assert(
    TRANSLATION_RESPONSE_FORMAT.json_schema.schema.required.includes(
      "translation",
    ),
    "translation field is required",
  );
  assert(
    INTERFACE_RESPONSE_FORMAT.json_schema.strict,
    "interface repair schema is strict",
  );
});

Deno.test("provider response schema requires word metadata", () => {
  const tokensSchema = TRANSLATION_RESPONSE_FORMAT.json_schema.schema.properties
    .tokens as { minItems?: number };
  assert(
    tokensSchema.minItems === 1,
    "a successful translation must include at least one token",
  );
});

Deno.test("provider validation failures expose bounded structural reasons", () => {
  assert(
    providerResultFailureReason("not json") === "invalid_response_json",
    "invalid JSON reason",
  );
  assert(
    providerResultFailureReason("[]") === "invalid_response_shape",
    "invalid shape reason",
  );
  assert(
    providerResultFailureReason('{"mode":"none"}') ===
      "missing_translation",
    "missing translation reason",
  );
  assert(
    providerResultFailureReason('{"translation":"Hallo"}') ===
      "contract_semantics",
    "remaining semantic reason",
  );
});

Deno.test("provider keeps full text when optional token metadata is invalid", () => {
  const valid = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "en",
      translation: "Hallo!",
      interfaceText: "Привіт!",
      explanation: null,
      confidence: null,
      tokens: [
        { text: "Hallo", gloss: "Привіт", isContent: true },
        { text: "!", isContent: false },
      ],
    }),
    "Hello!",
    "de",
    "uk",
  );
  assert(valid?.translation === "Hallo!", "learning output is retained");

  const degraded = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "en",
      translation: "Hallo!",
      interfaceText: "Hello!",
      explanation: null,
      confidence: null,
      tokens: [{ text: "Falsch", isContent: true }],
    }),
    "Hello!",
    "de",
    "en",
  );
  assert(degraded?.translation === "Hallo!", "full translation should pass");
  assert(degraded?.tokens.length === 0, "invalid tokens should be discarded");
});

Deno.test("provider trims boundary-only token whitespace", () => {
  const result = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "en",
      translation: "Привіт",
      interfaceText: "Привіт",
      explanation: null,
      confidence: null,
      tokens: [
        {
          text: "Привіт",
          gloss: "Hello",
          roman: "Pryvit",
          isContent: true,
        },
        { text: " ", gloss: null, roman: null, isContent: false },
      ],
      formAlternatives: null,
    }),
    "Hi",
    "uk",
    "uk",
  );

  assert(result !== null, "valid translation should pass");
  assert(result?.tokens.length === 1, "trailing whitespace token is removed");
  assert(
    (result?.tokens[0] as { text?: string })?.text === "Привіт",
    "word metadata stays attached to the translated word",
  );
});

Deno.test("provider repairs token punctuation without losing word metadata", () => {
  const result = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "en",
      translation: "Я набираю дуже довгий текст.",
      interfaceText: "I am typing a very long text.",
      explanation: null,
      confidence: null,
      tokens: [
        { text: "Я", gloss: "I", roman: "Ya", isContent: true },
        { text: " ", gloss: null, roman: null, isContent: false },
        {
          text: "набираю",
          gloss: "am typing",
          roman: "nabyrayu",
          isContent: true,
        },
        { text: " ", gloss: null, roman: null, isContent: false },
        { text: "дуже", gloss: "very", roman: "duzhe", isContent: true },
        { text: " ", gloss: null, roman: null, isContent: false },
        {
          text: "довгий",
          gloss: "long",
          roman: "dovhyi",
          isContent: true,
        },
        { text: " ", gloss: null, roman: null, isContent: false },
        {
          text: "текст",
          gloss: "text",
          roman: "tekst",
          isContent: true,
        },
        { text: " ", gloss: null, roman: null, isContent: false },
      ],
      formAlternatives: null,
    }),
    "I am typing a very long text.",
    "uk",
    "en",
  );

  assert(result !== null, "valid translation should pass");
  assert(
    result !== null && result.tokens.length > 0,
    "word metadata is retained",
  );
  assert(
    result?.tokens.map((token) => (token as { text: string }).text).join("") ===
      "Я набираю дуже довгий текст.",
    "repaired tokens reproduce the translated sentence exactly",
  );
});

Deno.test("provider canonicalizes punctuation-bound Latin word metadata", () => {
  const result = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "en",
      translation: "¿Hola?",
      interfaceText: "Hello?",
      explanation: null,
      confidence: null,
      tokens: [
        {
          text: "¿Hola?",
          gloss: "Hello",
          roman: null,
          isContent: true,
        },
      ],
      formAlternatives: null,
    }),
    "Hello?",
    "es",
    "en",
  );

  assert(result !== null, "valid translation should pass");
  assert(result?.tokens.length === 3, "punctuation becomes non-content");
  assert(
    (result?.tokens[1] as { text?: string }).text === "Hola",
    "meaning metadata remains attached to the visible word",
  );
  assert(
    (result?.tokens[1] as { roman?: string }).roman === "Hola",
    "Latin words receive complete pronunciation metadata",
  );
});

Deno.test("every learning language requests pronunciation metadata", () => {
  for (
    const language of [
      "en",
      "nl",
      "fr",
      "de",
      "hi",
      "it",
      "pt",
      "es",
      "ta",
      "tr",
      "uk",
    ]
  ) {
    const prompt = systemPrompt("auto", language, "en");
    assert(
      prompt.includes(
        'For each content token include "roman", a Latin-script transliteration.',
      ),
      `${language} requires pronunciation metadata`,
    );
  }
});

Deno.test("provider discards phrase-sized content tokens", () => {
  const result = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "uk",
      translation: "You can use Google speech.",
      interfaceText: "Можна використовувати Google speech.",
      explanation: null,
      confidence: null,
      tokens: [
        {
          text: "You can use Google speech",
          gloss: "whole phrase",
          roman: null,
          isContent: true,
        },
        { text: ".", gloss: null, roman: null, isContent: false },
      ],
    }),
    "Можна використовувати Google speech.",
    "en",
    "uk",
  );

  assert(result !== null, "valid full-message translation should pass");
  assert(
    result?.translation === "You can use Google speech.",
    "full translation should be retained",
  );
  assert(
    result?.tokens.length === 0,
    "phrase-sized content tokens should be discarded",
  );
});

Deno.test("provider-added paragraph breaks are removed for single-paragraph input", () => {
  const result = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "de",
      translation:
        "I need the document from you.\n\nSo I have a better understanding of what happened.",
      interfaceText:
        "I need the document from you.\n\nSo I have a better understanding of what happened.",
      explanation: null,
      confidence: null,
      tokens: [
        {
          text:
            "I need the document from you.\n\nSo I have a better understanding of what happened.",
          gloss: "full message",
          isContent: true,
        },
      ],
    }),
    "Ich brauche das Dokument von dir, damit ich besser verstehe was passiert ist.",
    "en",
    "en",
  );
  assert(result !== null, "valid translation should pass");
  assert(
    result?.translation ===
      "I need the document from you. So I have a better understanding of what happened.",
    "provider must not introduce paragraph breaks",
  );
  assert(
    result?.interfaceText === result?.translation,
    "interface lane follows normalized learning lane",
  );
  assert(
    result?.tokens.length === 0,
    "tokens containing provider-added line breaks should be discarded",
  );
});

Deno.test("provider mode drift is normalized instead of hiding translation", () => {
  const translated = parseProviderResult(
    JSON.stringify({
      mode: "none",
      sourceLang: "English",
      translation: "Hallo!",
      interfaceText: "Hello!",
      explanation: "unexpected model metadata",
      confidence: "high",
    }),
    "Hello!",
    "de",
    "en",
  );
  assert(translated?.mode === "translation", "non-target source mode");
  assert(translated?.sourceLang === "en", "language name normalization");
  assert(translated?.explanation === null, "translation explanation removed");
  assert(translated?.tokens.length === 0, "missing optional tokens degrade");

  const conservative = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "de",
      translation: "Hallo!",
    }),
    "Hallo",
    "de",
    "en",
  );
  assert(conservative?.mode === "none", "unsafe rewrite is discarded");
  assert(conservative?.translation === "Hallo", "authored text is retained");
  assert(
    conservative !== null &&
      interfaceOutputNeedsRetry(conservative, "de", "en"),
    "missing interface rendering requests repair",
  );
});

Deno.test("copied learning text requests an interface retry for every source", () => {
  for (
    const candidate of [
      {
        mode: "none",
        sourceLang: "de",
        translation: "Hallo!!",
        interfaceText: "Hallo!!",
        explanation: null,
        confidence: null,
        tokens: [{ text: "Hallo!!", gloss: "Hello", isContent: true }],
        input: "Hallo!!",
      },
      {
        mode: "translation",
        sourceLang: "es",
        translation: "Was machst du?",
        interfaceText: "Was machst du?",
        explanation: null,
        confidence: null,
        tokens: [
          {
            text: "Was machst du?",
            gloss: "What are you doing?",
            isContent: true,
          },
        ],
        input: "¿Qué estás haciendo?",
      },
    ]
  ) {
    const { input, ...providerOutput } = candidate;
    const copied = parseProviderResult(
      JSON.stringify(providerOutput),
      input,
      "de",
      "en",
    );
    assert(copied !== null, "copied output remains structurally valid");
    assert(
      interfaceOutputNeedsRetry(copied!, "de", "en"),
      `copied ${candidate.sourceLang} output should trigger a retry`,
    );
  }

  const translated = {
    mode: "none" as const,
    sourceLang: "de",
    translation: "Hallo!!",
    interfaceText: "Hello!!",
    explanation: null,
    confidence: null,
    tokens: [],
    formAlternatives: null,
  };
  assert(
    !interfaceOutputNeedsRetry(translated, "de", "en"),
    "translated interface text should not retry",
  );
});

Deno.test("provider accepts a source outside the learning-language list", () => {
  const result = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "other",
      translation: "Hallo!",
      interfaceText: "Hello!",
      explanation: null,
      confidence: null,
      tokens: [
        { text: "Hallo", gloss: "Hello", isContent: true },
        { text: "!", isContent: false },
      ],
    }),
    "こんにちは！",
    "de",
    "en",
  );
  assert(result?.sourceLang === "other", "arbitrary source should pass");
});

Deno.test("provider keeps a usable translation when optional word metadata is missing", () => {
  const withoutTokens = {
    mode: "translation" as const,
    sourceLang: "en",
    translation: "Привіт",
    interfaceText: "Hello",
    explanation: null,
    confidence: null,
    tokens: [],
    formAlternatives: null,
  };
  assert(
    !translationNeedsRetry(withoutTokens, "uk", "Hello"),
    "missing popup metadata does not fail the translation",
  );

  const withoutRomanization = {
    ...withoutTokens,
    tokens: [
      { text: "Привіт", gloss: "Hello", roman: null, isContent: true },
    ],
  };
  assert(
    !translationNeedsRetry(withoutRomanization, "uk", "Hello"),
    "missing romanization does not fail the translation",
  );

  const emojiOnly = {
    ...withoutTokens,
    sourceLang: "uk",
    translation: "👍",
    interfaceText: "👍",
  };
  assert(
    !translationNeedsRetry(emojiOnly, "uk", "👍"),
    "messages without words do not need word metadata",
  );
});

Deno.test("provider retries only when a cross-language result copies the source", () => {
  const copied = {
    mode: "translation" as const,
    sourceLang: "uk",
    translation: "Давай подивимось 🙈",
    interfaceText: "Давай подивимось 🙈",
    explanation: null,
    confidence: null,
    tokens: [],
    formAlternatives: null,
  };
  assert(
    translationNeedsRetry(copied, "en", "Давай подивимось 🙈"),
    "copied cross-language output is still rejected",
  );
});

Deno.test("auto-source prompt requests learning output with localized glosses", () => {
  const prompt = systemPrompt("auto", "uk", "es");
  assert(prompt.includes("Detect the input language"), "source detection");
  assert(
    prompt.includes("keyboard-adjacent typos"),
    "source detection handles misspelled short text",
  );
  assert(
    prompt.includes("interface language as a weak hint"),
    "ambiguous malformed text gets a bounded locale hint",
  );
  assert(prompt.includes('"translation"'), "target-language output");
  assert(prompt.includes("Spanish"), "selected interface language");
  assert(prompt.includes('"sourceLang"'), "detected source output");
  assert(prompt.includes("sourceLang=other"), "arbitrary source fallback");
  assert(prompt.includes("mode=correction"), "same-language correction mode");
  assert(
    prompt.includes("mode MUST be translation"),
    "non-target sources require translation mode",
  );
  assert(
    prompt.includes("mode=none applies only to correction"),
    "none still requires interface translation",
  );
  assert(
    prompt.includes("carefully check the complete input"),
    "corrections require a full-message error check",
  );
  assert(
    prompt.includes("Even one wrong word or misspelled word is enough"),
    "small real mistakes should still become corrections",
  );
  assert(
    prompt.includes("Do not correct capitalization, punctuation"),
    "chat style is not over-corrected",
  );
  assert(
    prompt.includes("never depends on whether the viewer authored"),
    "provider output stays neutral between author and recipient",
  );
  assert(
    prompt.includes("Preserve paragraph breaks exactly"),
    "provider must not invent paragraph breaks",
  );
  assert(
    prompt.includes(
      "URLs, @mentions, hashtags, code, numbers, and emoji unchanged",
    ),
    "protected content stays exact while surrounding language moves naturally",
  );
  assert(
    prompt.includes("brb and ttyl"),
    "meaning-bearing chat abbreviations are translated naturally",
  );
  assert(
    prompt.includes("repeated letters, stretched vowels or consonants"),
    "expressive stretching does not become an unsupported source",
  );
  assert(
    prompt.includes("likely personal name is not an unsupported language"),
    "names are transliterated instead of treated as unsupported",
  );
  assert(
    prompt.includes(
      "capitalization, noun capitalization, apostrophes, commas, terminal punctuation, or spacing",
    ),
    "mechanical fixes stay silent",
  );
});

Deno.test("prompt names every supported interface language correctly", () => {
  for (
    const [code, name] of [
      ["en", "English"],
      ["uk", "Ukrainian"],
      ["de", "German"],
      ["es", "Spanish"],
    ]
  ) {
    const prompt = systemPrompt("auto", "de", code);
    assert(
      prompt.includes(`interface language is ${name} (${code})`),
      `${code} interface locale should be named explicitly`,
    );
    assert(
      prompt.includes(`complete ${name} interface-language line`),
      `${code} interface output should be requested explicitly`,
    );
  }
});

Deno.test("author can receive a bounded same-language correction", () => {
  const result = parseProviderResult(
    JSON.stringify({
      mode: "correction",
      sourceLang: "de",
      translation: "Machst du ...?",
      interfaceText: "Machst du ...?",
      explanation: "Das Verb muss zu du passen.",
      confidence: "medium",
      tokens: [
        {
          text: "Machst du",
          gloss: "do you",
          isContent: true,
        },
        { text: " ...?", isContent: false },
      ],
    }),
    "Machen du",
    "de",
    "de",
  );
  assert(result?.mode === "correction", "correction should pass");
  assert(result?.confidence === "medium", "confidence should pass");
});

Deno.test("same-language correction is available to any eligible viewer", () => {
  const none = parseProviderResult(
    JSON.stringify({
      mode: "none",
      sourceLang: "de",
      translation: "Machen du",
      interfaceText: "What are you doing?",
      explanation: null,
      confidence: null,
      tokens: [
        { text: "Machen du", gloss: "do you", isContent: true },
      ],
    }),
    "Machen du",
    "de",
    "en",
  );
  assert(none?.mode === "none", "recipient none should pass");

  const correction = parseProviderResult(
    JSON.stringify({
      mode: "correction",
      sourceLang: "de",
      translation: "Machst du ...?",
      interfaceText: "What are you doing?",
      explanation: "Verb agreement.",
      confidence: "medium",
      tokens: [
        { text: "Machst du ...?", gloss: "do you", isContent: true },
      ],
    }),
    "Machen du",
    "de",
    "en",
  );
  assert(correction?.mode === "correction", "recipient correction should pass");
});

Deno.test("server accepts corrected interface-language text for translated source mistakes", () => {
  const valid = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "en",
      translation: "Was machst du?",
      interfaceText: "What is you doing?",
      explanation: null,
      confidence: null,
      tokens: [
        {
          text: "Was machst du?",
          gloss: "what are you doing",
          isContent: true,
        },
      ],
    }),
    "What is you doing?",
    "de",
    "en",
  );
  assert(valid !== null, "exact authored interface text should pass");

  const rewritten = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "en",
      translation: "Was machst du?",
      interfaceText: "What are you doing?",
      explanation: null,
      confidence: null,
      tokens: [
        {
          text: "Was machst du?",
          gloss: "what are you doing",
          isContent: true,
        },
      ],
    }),
    "What is you doing?",
    "de",
    "en",
  );
  assert(rewritten !== null, "valid translation should not be discarded");
  assert(
    rewritten?.interfaceText === "What are you doing?",
    "server should keep the corrected interface line for main-chat display",
  );
});

Deno.test("server keeps duplicate target and interface lanes identical", () => {
  const result = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "en",
      translation: "Was meinst du?",
      interfaceText: "Was sprechen Sie?",
      explanation: null,
      confidence: null,
      tokens: [
        {
          text: "Was meinst du?",
          gloss: "what do you mean",
          isContent: true,
        },
      ],
    }),
    "What do you mean?",
    "de",
    "de",
  );
  assert(result !== null, "valid translation should not be discarded");
  assert(
    result?.interfaceText === "Was meinst du?",
    "server must copy the trusted learning line into the interface lane",
  );
});

Deno.test("maximum character contract remains 2000", () => {
  assert(characterCount("a".repeat(MAX_CHARS)) === MAX_CHARS, "maximum length");
});
