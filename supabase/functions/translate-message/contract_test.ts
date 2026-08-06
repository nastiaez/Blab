import {
  characterCount,
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
  validateRequest,
} from "./contract.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

Deno.test("counts user-perceived characters", () => {
  assert(characterCount("a") === 1, "ASCII character count");
  assert(characterCount("👨‍👩‍👧‍👦") === 1, "joined emoji character count");
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

Deno.test("provider prompt forbids gender guessing and preserves address", () => {
  const prompt = systemPrompt("auto", "uk", "de");
  assert(
    prompt.includes(
      "Never guess gender from a name, profile name, username, message topic, or text style.",
    ),
    "provider must not infer gender from weak signals",
  );
  assert(
    prompt.includes(
      "Use gendered wording only when explicit pronouns or gender metadata are provided.",
    ),
    "gendered wording needs explicit metadata",
  );
  assert(
    prompt.includes(
      "If the source language is ambiguous, use neutral wording that avoids adding gender.",
    ),
    "ambiguous sources need neutral output",
  );
  assert(
    prompt.includes(
      "Preserve informal/formal address exactly when the source marks it.",
    ),
    "du/Sie and equivalent address should be preserved",
  );
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
      "Do not use parenthetical or slash gender alternatives",
    ),
    "prompt must explicitly reject both-gender workaround forms",
  );
});

Deno.test("prompt includes Ukrainian and German neutral-gender examples", () => {
  const prompt = systemPrompt("auto", "de", "en");
  assert(
    prompt.includes(
      'English "I was happy to help" to Ukrainian: prefer "Мені було приємно допомогти"',
    ),
    "Ukrainian ambiguous speaker examples should avoid gendered past-tense adjectives",
  );
  assert(
    prompt.includes(
      'English "I was glad to see you" to Ukrainian: prefer "Мені було приємно побачитись з тобою"',
    ),
    "Ukrainian ambiguous speaker examples should still use natural conversational wording",
  );
  assert(
    prompt.includes(
      'English "I am your friend" to German: prefer "Ich bin mit dir befreundet"',
    ),
    "German ambiguous speaker examples should avoid Freund/Freundin guesses",
  );
});

Deno.test("prompt includes Ukrainian to German informal address example", () => {
  const prompt = systemPrompt("auto", "de", "en");
  assert(
    prompt.includes(
      'Ukrainian "Ти дивишся..." to German: prefer informal "Du schaust..."',
    ),
    "Ukrainian informal address must be anchored to German du examples",
  );
});

Deno.test("interface repair prompt reuses the gender and address rules", () => {
  const prompt = interfaceRepairSystemPrompt("de", "uk");
  assert(
    prompt.includes("Never guess gender from a name"),
    "interface repair must not lose the main translation gender/address contract",
  );
  assert(
    prompt.includes('English "I was happy to help" to Ukrainian'),
    "interface repair should keep the Ukrainian neutral-gender example",
  );
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
