import {
  characterCount,
  correctionNeedsRetry,
  focusedTranslationRetryMessages,
  FORM_AUDIT_RESPONSE_FORMAT,
  formAuditSystemPrompt,
  type FormParticipantContext,
  genderedAmbiguityNeedsRetry,
  INTERFACE_RESPONSE_FORMAT,
  interfaceOutputNeedsRetry,
  interfaceRepairSystemPrompt,
  MAX_CHARS,
  OPENROUTER_PROVIDER,
  parseFormAuditResult,
  parseProviderResult,
  providerCredentials,
  providerMessages,
  providerResultFailureReason,
  recognizedAbbreviationSourceLanguage,
  systemPrompt,
  TRANSLATION_RESPONSE_FORMAT,
  type TranslationContextMessage,
  translationNeedsRetry,
  type TranslationResult,
  unsupportedSourceScript,
  validateRequest,
} from "./contract.ts";
import * as contract from "./contract.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

const ukFeminineAuditTokens = [
  { text: "Ти", gloss: "you", roman: "Ty", isContent: true },
  { text: " ", gloss: null, roman: null, isContent: false },
  { text: "ходила", gloss: "went", roman: "khodyla", isContent: true },
  { text: " ", gloss: null, roman: null, isContent: false },
  {
    text: "вчора",
    gloss: "yesterday",
    roman: "vchora",
    isContent: true,
  },
  { text: "?", gloss: null, roman: null, isContent: false },
];

const ukMasculineAuditTokens = [
  { text: "Ти", gloss: "you", roman: "Ty", isContent: true },
  { text: " ", gloss: null, roman: null, isContent: false },
  { text: "ходив", gloss: "went", roman: "khodyv", isContent: true },
  { text: " ", gloss: null, roman: null, isContent: false },
  {
    text: "вчора",
    gloss: "yesterday",
    roman: "vchora",
    isContent: true,
  },
  { text: "?", gloss: null, roman: null, isContent: false },
];

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
    messages[0].content.includes("Do not translate this context block"),
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

Deno.test("provider messages include bounded source evidence", () => {
  const messages = providerMessages({
    sourceLang: "auto",
    targetLang: "de",
    interfaceLang: "en",
    text: "No",
    context: [
      { speaker: "partner", text: "I am not coming today", sourceLang: "en" },
      { speaker: "viewer", text: "Are you sure?" },
    ],
    formContext: {
      viewerName: "Bob",
      partnerName: "Alice",
      messageAuthor: "partner",
      viewerForm: null,
      partnerForm: null,
      tone: "informal",
      authorPrimaryKnownLanguage: "en",
    },
  });
  const system = messages[0].content;

  assert(
    system.includes("same sender"),
    "same-sender context is available as source evidence",
  );
  assert(
    system.includes("partner [source=en]: I am not coming today"),
    "trusted prior source labels are supplied with the matching context line",
  );
  assert(
    system.includes("primary known language is English (en)"),
    "the author's primary known language is a final hint",
  );
  assert(
    system.includes("translate only the current user message"),
    "context must remain excluded from translation input",
  );
});

Deno.test("focused short retry isolates semantic translation from source detection", () => {
  const messages = focusedTranslationRetryMessages({
    sourceLang: "en",
    targetLang: "de",
    interfaceLang: "en",
    text: "No",
    formContext: {
      viewerName: "Bob",
      partnerName: "Alice",
      messageAuthor: "partner",
      viewerForm: null,
      partnerForm: null,
      tone: "informal",
    },
  });

  assert(messages !== null, "a short pinned-source retry is eligible");
  const system = messages![0].content;
  assert(system.includes("English (en)"), "the source is pinned");
  assert(system.includes("German (de)"), "the target is explicit");
  assert(system.includes("complete utterance"), "one word remains a sentence");
  assert(system.includes("mode=translation"), "the retry cannot choose none");
  assert(
    system.includes("never transliterate the expanded English phrase"),
    "chat abbreviations must become an idiomatic target-language expression",
  );
  assert(
    messages![1].content === "No",
    "the authored message is the only user input",
  );
  assert(
    focusedTranslationRetryMessages({
      sourceLang: "en",
      targetLang: "de",
      interfaceLang: "en",
      text: "This message is deliberately longer than the bounded retry limit",
    }) === null,
    "long messages stay on the ordinary provider path",
  );
});

Deno.test("focused retry keeps its resolved source when provider parrots target", () => {
  const result = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "uk",
      translation: "Боже мій, Настя",
      interfaceText: "OMG Nastia",
      explanation: null,
      confidence: null,
      tokens: [],
      formAlternatives: null,
    }),
    "OMG Nastia",
    "uk",
    "en",
    "en",
  );
  assert(result !== null, "the focused response remains valid");
  assert(result!.sourceLang === "en", "the resolved source stays pinned");
  assert(result!.mode === "translation", "the target rendering is retained");
});

Deno.test("provider keeps private forms out while suggesting by name", () => {
  const formContext = {
    viewerName: "Alice",
    partnerName: "Bob",
    messageAuthor: "viewer" as const,
    viewerForm: "masculine" as const,
    partnerForm: "feminine" as const,
    tone: "informal" as const,
  };
  const prompt = systemPrompt("auto", "uk", "de", formContext);
  assert(
    prompt === systemPrompt("auto", "uk", "de", {
      ...formContext,
      viewerForm: null,
      partnerForm: null,
    }),
    "private saved forms must not alter the shared prompt",
  );
  assert(
    !prompt.includes("Viewer saved form") &&
      !prompt.includes("Partner saved form"),
    "private saved forms must not appear in the shared prompt",
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

  const required = parseAudit!(JSON.stringify({
    requiresChoice: true,
    subjectIsViewer: false,
    before: "Ти ",
    feminine: "ходила",
    masculine: "ходив",
    after: " вчора?",
    suggestedForm: "feminine",
    feminineTokens: ukFeminineAuditTokens,
    masculineTokens: ukMasculineAuditTokens,
  }));
  assert(
    required?.requiresChoice === true &&
      required.subjectIsViewer === false &&
      required.before === "Ти " && required.feminine === "ходила" &&
      required.masculine === "ходив" &&
      required.after === " вчора?",
    "a required partner form retains only the shortest changing fragment",
  );
  assert(
    parseAudit!(
      '{"requiresChoice":true,"subjectIsViewer":false,"before":null,"feminine":null,"masculine":null,"after":null}',
    ) === null,
    "a required choice without both exact fragments is rejected",
  );

  const neutral = parseAudit!(JSON.stringify({
    requiresChoice: false,
    subjectIsViewer: null,
    before: null,
    feminine: null,
    masculine: null,
    after: null,
    suggestedForm: null,
    feminineTokens: null,
    masculineTokens: null,
  }));
  assert(
    neutral?.requiresChoice === false && neutral.subjectIsViewer === null &&
      neutral.before === null && neutral.feminine === null &&
      neutral.masculine === null && neutral.after === null,
    "a genuinely form-neutral sentence is accepted",
  );
});

Deno.test("focused grammatical-form audit requires complete token metadata for both renderings", () => {
  const valid = parseFormAuditResult(JSON.stringify({
    requiresChoice: true,
    subjectIsViewer: false,
    before: "Ти ",
    feminine: "ходила",
    masculine: "ходив",
    after: " вчора?",
    suggestedForm: "masculine",
    feminineTokens: ukFeminineAuditTokens,
    masculineTokens: ukMasculineAuditTokens,
  }));
  if (
    valid === null || valid.feminineTokens === null ||
    valid.masculineTokens === null
  ) {
    throw new Error("valid form audit token metadata was rejected");
  }
  assert(
    valid.feminineTokens.map((token) => token.text).join("") ===
        "Ти ходила вчора?" &&
      valid.masculineTokens.map((token) => token.text).join("") ===
        "Ти ходив вчора?",
    "both complete form renderings retain validated token metadata",
  );

  const missingRoman = JSON.parse(JSON.stringify({
    ...valid,
    feminineTokens: valid.feminineTokens.map((token) =>
      token.text === "ходила" ? { ...token, roman: null } : token
    ),
  }));
  assert(
    parseFormAuditResult(JSON.stringify(missingRoman)) === null,
    "non-Latin content tokens without romanization are rejected",
  );

  const nonLatinRomanization = JSON.parse(JSON.stringify({
    ...valid,
    feminineTokens: valid.feminineTokens.map((token) =>
      token.text === "ходила" ? { ...token, roman: "ходила" } : token
    ),
  }));
  assert(
    parseFormAuditResult(JSON.stringify(nonLatinRomanization)) === null,
    "romanization for non-Latin content must itself use Latin script",
  );

  const mismatchedMasculine = {
    ...valid,
    masculineTokens: valid.masculineTokens.map((token) =>
      token.text === "ходив" ? { ...token, text: "ходила" } : token
    ),
  };
  assert(
    parseFormAuditResult(JSON.stringify(mismatchedMasculine)) === null,
    "each form token array must reproduce its complete sentence exactly",
  );
});

Deno.test("strict form schemas require both complete token arrays", () => {
  const translationAlternatives = TRANSLATION_RESPONSE_FORMAT.json_schema.schema
    .properties.formAlternatives as {
      required?: readonly string[];
      properties?: Record<string, unknown>;
    };
  assert(
    translationAlternatives.required?.includes("feminineTokens") === true &&
      translationAlternatives.required?.includes("masculineTokens") === true,
    "translation alternatives require both token arrays",
  );
  const audit = FORM_AUDIT_RESPONSE_FORMAT.json_schema.schema as {
    required: readonly string[];
  };
  assert(
    audit.required.includes("feminineTokens") &&
      audit.required.includes("masculineTokens"),
    "the focused audit requires both token arrays",
  );
});

Deno.test("provider alternatives retain complete tokens for both forms", () => {
  const result = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "en",
      translation: "Ти ходила вчора?",
      interfaceText: "Did you go yesterday?",
      explanation: null,
      confidence: null,
      tokens: ukFeminineAuditTokens,
      formAlternatives: {
        before: "Ти ",
        feminine: "ходила",
        masculine: "ходив",
        after: " вчора?",
        subjectName: "Bob",
        subjectIsViewer: false,
        suggestedForm: "masculine",
        feminineTokens: ukFeminineAuditTokens,
        masculineTokens: ukMasculineAuditTokens,
      },
    }),
    "Did you go yesterday?",
    "uk",
    "en",
  );
  assert(
    result?.formAlternatives?.feminineTokens.map((token) => token.text).join(
          "",
        ) === "Ти ходила вчора?" &&
      result.formAlternatives.masculineTokens.map((token) => token.text).join(
          "",
        ) === "Ти ходив вчора?",
    "both validated token arrays survive provider parsing",
  );
});

Deno.test("focused audit prompt localizes word metadata", () => {
  const prompt = formAuditSystemPrompt("en", "uk", "es", {
    viewerName: "Alice",
    partnerName: "Bob",
    messageAuthor: "viewer",
    viewerForm: null,
    partnerForm: null,
    tone: "informal",
  });
  assert(
    prompt.includes("Spanish (es)") &&
      prompt.includes("1-3 word Spanish gloss"),
    "the audit receives the interface language for localized glosses",
  );
  assert(
    prompt.includes("Alice") && prompt.includes("Bob"),
    "the audit receives both participant names",
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
        feminineTokens: unknown[];
        masculineTokens: unknown[];
      } | null,
      audit: {
        requiresChoice: boolean;
        subjectIsViewer: boolean | null;
        before: string | null;
        feminine: string | null;
        masculine: string | null;
        after: string | null;
        feminineTokens: unknown[] | null;
        masculineTokens: unknown[] | null;
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
    after: " вчора?",
    suggestedForm: "feminine" as const,
    feminineTokens: ukFeminineAuditTokens,
    masculineTokens: ukMasculineAuditTokens,
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
        after: " вчора?",
        feminineTokens: ukFeminineAuditTokens,
        masculineTokens: ukMasculineAuditTokens,
      },
      audit,
    ),
    "the minimal verb alternatives match",
  );
  assert(
    !matchesAudit!(
      {
        before: "",
        feminine: "Ти ходила вчора?",
        masculine: "Ти ходив вчора?",
        after: "",
        subjectName: "Bob",
        subjectIsViewer: false,
        feminineTokens: ukFeminineAuditTokens,
        masculineTokens: ukMasculineAuditTokens,
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
        feminineTokens: unknown[] | null;
        masculineTokens: unknown[] | null;
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
      feminineTokens: unknown[];
      masculineTokens: unknown[];
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
    after: " вчора?",
    suggestedForm: "feminine" as const,
    feminineTokens: ukFeminineAuditTokens,
    masculineTokens: ukMasculineAuditTokens,
  };
  const result = {
    mode: "translation" as const,
    sourceLang: "en",
    translation: "Ти ходила вчора?",
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
      alternatives.after === " вчора?" &&
      alternatives.subjectName === "Bob" &&
      alternatives.subjectIsViewer === false &&
      JSON.stringify(alternatives.feminineTokens) ===
        JSON.stringify(ukFeminineAuditTokens) &&
      JSON.stringify(alternatives.masculineTokens) ===
        JSON.stringify(ukMasculineAuditTokens),
    "the omitted provider object is rebuilt from the confirmed minimal split",
  );
  assert(
    alternativesFromAudit!(
      { ...result, translation: "Ти ходив вчора?" },
      audit,
      formContext,
    ) === null,
    "the audit cannot overwrite a different rendered translation",
  );
});

Deno.test("confirmed audit makes feminine translation metadata canonical", () => {
  const applyAudit = (contract as unknown as {
    applyConfirmedFormAudit?: (
      result: Record<string, unknown>,
      audit: Record<string, unknown>,
      formContext: Record<string, unknown>,
    ) => {
      translation: string;
      tokens: unknown[];
      formAlternatives: {
        feminineTokens: unknown[];
        masculineTokens: unknown[];
      };
    } | null;
  }).applyConfirmedFormAudit;
  assert(
    typeof applyAudit === "function",
    "the audited rendering must be applied as one validated operation",
  );
  const applied = applyAudit!(
    {
      mode: "translation",
      sourceLang: "en",
      translation: "Ти ходив вчора?",
      interfaceText: "Did you go yesterday?",
      explanation: null,
      confidence: null,
      tokens: ukMasculineAuditTokens,
      formAlternatives: null,
    },
    {
      requiresChoice: true,
      subjectIsViewer: false,
      before: "Ти ",
      feminine: "ходила",
      masculine: "ходив",
      after: " вчора?",
      suggestedForm: "masculine",
      feminineTokens: ukFeminineAuditTokens,
      masculineTokens: ukMasculineAuditTokens,
    },
    {
      viewerName: "Alice",
      partnerName: "Bob",
      messageAuthor: "viewer",
      viewerForm: null,
      partnerForm: null,
      tone: "informal",
    },
  );
  assert(
    applied?.translation === "Ти ходила вчора?" &&
      JSON.stringify(applied.tokens) ===
        JSON.stringify(ukFeminineAuditTokens) &&
      JSON.stringify(applied.formAlternatives.feminineTokens) ===
        JSON.stringify(ukFeminineAuditTokens) &&
      JSON.stringify(applied.formAlternatives.masculineTokens) ===
        JSON.stringify(ukMasculineAuditTokens),
    "canonical translation and top-level tokens use the feminine rendering",
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

Deno.test("provider retries a misclassified short source", () => {
  const misclassified = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "ta",
      translation: "மன்னிக்கவும்",
      interfaceText: "sorry",
      explanation: null,
      confidence: null,
      tokens: [],
      formAlternatives: null,
    }),
    "sorry",
    "ta",
    "en",
  );

  assert(misclassified !== null, "the provider result remains parseable");
  assert(
    translationNeedsRetry(misclassified!, "ta", "sorry"),
    "discarding a plausible target-language rewrite must request one retry",
  );
});

type SourceEvidenceNeedsRetry = (args: {
  result: TranslationResult;
  sourceText: string;
  targetLang: string;
  context?: TranslationContextMessage[];
  formContext?: FormParticipantContext;
}) => boolean;

function sourceEvidenceRetry(): SourceEvidenceNeedsRetry {
  const candidate = (contract as unknown as {
    sourceEvidenceNeedsRetry?: SourceEvidenceNeedsRetry;
  }).sourceEvidenceNeedsRetry;
  assert(candidate !== undefined, "sourceEvidenceNeedsRetry must be exported");
  return candidate!;
}

Deno.test("source evidence retry rejects No misclassified as German", () => {
  const noAsGerman = parseProviderResult(
    JSON.stringify({
      mode: "none",
      sourceLang: "de",
      translation: "No",
      interfaceText: "No",
      explanation: null,
      confidence: null,
      tokens: [],
      formAlternatives: null,
    }),
    "No",
    "de",
    "en",
  );
  assert(noAsGerman !== null, "the provider result is valid");
  assert(
    sourceEvidenceRetry()({
      result: noAsGerman!,
      sourceText: "No",
      targetLang: "de",
      context: [{
        speaker: "partner",
        text: "I am not coming today",
        sourceLang: "en",
      }],
      formContext: {
        viewerName: "Bob",
        partnerName: "Alice",
        messageAuthor: "partner",
        viewerForm: null,
        partnerForm: null,
        tone: "informal",
        authorPrimaryKnownLanguage: "en",
      },
    }),
    "same-sender English evidence must reject the German classification",
  );
});

Deno.test("source evidence selects the author's language for the bounded retry", () => {
  const copiedEnglish = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "en",
      translation: "No",
      interfaceText: "No",
      explanation: null,
      confidence: null,
      tokens: [],
      formAlternatives: null,
    }),
    "No",
    "de",
    "en",
  );
  assert(copiedEnglish !== null, "the copied provider result is valid");

  const selectRetryLanguage = (contract as unknown as {
    sourceEvidenceLanguage?: (input: {
      result: TranslationResult;
      sourceText: string;
      targetLang: string;
      context?: TranslationContextMessage[];
      formContext?: FormParticipantContext;
    }) => string | null;
  }).sourceEvidenceLanguage;
  assert(selectRetryLanguage !== undefined, "source evidence language exists");
  assert(
    selectRetryLanguage!({
      result: copiedEnglish!,
      sourceText: "No",
      targetLang: "de",
      context: [{
        speaker: "partner",
        text: "I am not coming today",
        sourceLang: "en",
      }],
      formContext: {
        viewerName: "Bob",
        partnerName: "Alice",
        messageAuthor: "partner",
        viewerForm: null,
        partnerForm: null,
        tone: "informal",
        authorPrimaryKnownLanguage: "en",
      },
    }) === "en",
    "the one retry must pin an ambiguous English utterance to English",
  );
});

Deno.test("source evidence retry preserves genuine target-language text", () => {
  const german = parseProviderResult(
    JSON.stringify({
      mode: "none",
      sourceLang: "de",
      translation: "Nein",
      interfaceText: "No",
      explanation: null,
      confidence: null,
      tokens: [],
      formAlternatives: null,
    }),
    "Nein",
    "de",
    "en",
  );
  assert(german !== null, "the provider result is valid");
  assert(
    !sourceEvidenceRetry()({
      result: german!,
      sourceText: "Nein",
      targetLang: "de",
      context: [],
      formContext: {
        viewerName: "Alice",
        partnerName: "Bob",
        messageAuthor: "viewer",
        viewerForm: null,
        partnerForm: null,
        tone: "informal",
        authorPrimaryKnownLanguage: "de",
      },
    }),
    "matching target-language evidence must remain accepted",
  );
});

Deno.test("source evidence retry recognizes an abbreviation plus a name", () => {
  const translated = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "other",
      translation: "Oh mein Gott, Nastia!",
      interfaceText: "OMG Nastia",
      explanation: null,
      confidence: null,
      tokens: [],
      formAlternatives: null,
    }),
    "OMG Nastia",
    "de",
    "en",
  );
  assert(translated !== null, "the provider result is valid");
  const formContext: FormParticipantContext = {
    viewerName: "Alice",
    partnerName: "Nastia",
    messageAuthor: "viewer",
    viewerForm: null,
    partnerForm: null,
    tone: "informal",
    authorPrimaryKnownLanguage: "en",
  };

  assert(
    sourceEvidenceRetry()({
      result: translated!,
      sourceText: "OMG Nastia",
      targetLang: "de",
      formContext,
    }),
    "known English abbreviation plus participant name must be reclassified",
  );
  assert(
    !sourceEvidenceRetry()({
      result: translated!,
      sourceText: "你好 Nastia",
      targetLang: "de",
      formContext,
    }),
    "unsupported-script content must remain unsupported",
  );
  assert(
    !sourceEvidenceRetry()({
      result: translated!,
      sourceText: "Hello Stranger",
      targetLang: "de",
      formContext,
    }),
    "capitalization without a recognized abbreviation is not enough",
  );
});

Deno.test("source evidence pins a recognized English abbreviation without history", () => {
  assert(
    recognizedAbbreviationSourceLanguage("OMG Nastia") === "en",
    "recognized English chat abbreviations provide source evidence immediately",
  );
  const translated = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "other",
      translation: "हे भगवान, नास्त्या",
      interfaceText: "OMG Nastia",
      explanation: null,
      confidence: null,
      tokens: [],
      formAlternatives: null,
    }),
    "OMG Nastia",
    "hi",
    "en",
  );
  assert(translated !== null, "the provider result is valid");

  const selectRetryLanguage = (contract as unknown as {
    sourceEvidenceLanguage?: (input: {
      result: TranslationResult;
      sourceText: string;
      targetLang: string;
      context?: TranslationContextMessage[];
      formContext?: FormParticipantContext;
    }) => string | null;
  }).sourceEvidenceLanguage;
  assert(selectRetryLanguage !== undefined, "source evidence language exists");
  assert(
    selectRetryLanguage!({
      result: translated!,
      sourceText: "OMG Nastia",
      targetLang: "hi",
      context: [],
      formContext: {
        viewerName: "Bob",
        partnerName: "Alice",
        messageAuthor: "partner",
        viewerForm: null,
        partnerForm: null,
        tone: "informal",
        authorPrimaryKnownLanguage: null,
      },
    }) === "en",
    "a recognized English abbreviation must provide the bounded retry source",
  );
});

Deno.test("unsupported source scripts are recognized without provider guessing", () => {
  assert(unsupportedSourceScript("你好，Bob。"), "Han script is unsupported");
  assert(unsupportedSourceScript("مرحبا"), "Arabic script is unsupported");
  assert(!unsupportedSourceScript("Hello Bob"), "Latin script is supported");
  assert(
    !unsupportedSourceScript("Привіт Bob"),
    "Cyrillic script is supported",
  );
  assert(
    !unsupportedSourceScript("नमस्ते Bob"),
    "Devanagari script is supported",
  );
  assert(!unsupportedSourceScript("வணக்கம் Bob"), "Tamil script is supported");
  assert(!unsupportedSourceScript("👋 123"), "non-letter content is neutral");
});

Deno.test("abbreviation plus name source evidence covers every target language", () => {
  const translated: TranslationResult = {
    mode: "translation",
    sourceLang: "other",
    translation: "translated",
    interfaceText: "OMG Nastia",
    explanation: null,
    confidence: null,
    tokens: [],
    formAlternatives: null,
  };
  const formContext: FormParticipantContext = {
    viewerName: "Alice",
    partnerName: "Bob",
    messageAuthor: "viewer",
    viewerForm: null,
    partnerForm: null,
    tone: "informal",
    authorPrimaryKnownLanguage: "en",
  };

  for (
    const targetLang of [
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
    assert(
      sourceEvidenceRetry()({
        result: translated,
        sourceText: "OMG Nastia",
        targetLang,
        formContext,
      }),
      `OMG plus a name must be reclassified for ${targetLang}`,
    );
    assert(
      systemPrompt("auto", targetLang, "en", formContext).includes(
        "abbreviation combined with compatible Latin-script words or names",
      ),
      `the ${targetLang} prompt must keep abbreviation-plus-name supported`,
    );
  }
});

Deno.test("source classification retry preserves valid short messages", () => {
  const tamil = parseProviderResult(
    JSON.stringify({
      mode: "none",
      sourceLang: "ta",
      translation: "நன்றி",
      interfaceText: "thanks",
      explanation: null,
      confidence: null,
      tokens: [],
      formAlternatives: null,
    }),
    "நன்றி",
    "ta",
    "en",
  );
  assert(tamil !== null, "genuine Tamil remains parseable");
  assert(
    !translationNeedsRetry(tamil!, "ta", "நன்றி"),
    "genuine target-language text is not retried",
  );

  const correction = parseProviderResult(
    JSON.stringify({
      mode: "correction",
      sourceLang: "ta",
      translation: "நன்றி",
      interfaceText: "thanks",
      explanation: "Corrected the spelling.",
      confidence: "high",
      tokens: [],
      formAlternatives: null,
    }),
    "நன்ரி",
    "ta",
    "en",
  );
  assert(correction !== null, "valid correction remains parseable");
  assert(
    !translationNeedsRetry(correction!, "ta", "நன்ரி"),
    "a complete correction is not retried",
  );
});

Deno.test("source classification retry excludes non-conversational and long input", () => {
  for (
    const source of [
      "https://example.com",
      "👍",
      "sorry about missing the call yesterday",
    ]
  ) {
    const parsed = parseProviderResult(
      JSON.stringify({
        mode: "translation",
        sourceLang: "ta",
        translation: "மன்னிக்கவும்",
        interfaceText: source,
        explanation: null,
        confidence: null,
        tokens: [],
        formAlternatives: null,
      }),
      source,
      "ta",
      "en",
    );
    assert(parsed !== null, `${source} remains parseable`);
    assert(
      !translationNeedsRetry(parsed!, "ta", source),
      `${source} does not trigger the bounded source retry`,
    );
  }
});

Deno.test("source classification retry guidance is generic", () => {
  const guidance = (contract as Record<string, unknown>)[
    "sourceClassificationRetryGuidance"
  ];
  assert(typeof guidance === "function", "retry guidance helper exists");
  const text = (guidance as (targetLang: string) => string)("ta");
  assert(text.includes("Tamil"), "guidance names the learning language");
  assert(text.includes("Re-detect"), "guidance requests source re-detection");
  assert(
    text.includes("complete utterance"),
    "retry guidance treats a one-word message as a complete utterance",
  );
  assert(
    text.includes("semantic meaning"),
    "retry guidance requires the one-word meaning to be translated",
  );
  for (const example of ["sorry", "yes", "hello"]) {
    assert(!text.includes(example), `guidance does not hardcode ${example}`);
  }
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
