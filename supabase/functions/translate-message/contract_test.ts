import {
  characterCount,
  fetchProviderWithTimeout,
  INTERFACE_RESPONSE_FORMAT,
  interfaceOutputNeedsRetry,
  isShortAlphabeticText,
  MAX_CHARS,
  OPENROUTER_PROVIDER,
  parseProviderResult,
  providerCallFailureReason,
  PROVIDER_TIMEOUT_MS,
  ProviderTimeoutError,
  providerResultFailureReason,
  shortInputRetryGuidance,
  systemPrompt,
  TRANSLATION_RESPONSE_FORMAT,
  translationOutputNeedsRetry,
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
    prompt.includes("clear, objective grammar"),
    "corrections require an objective error",
  );
  assert(
    prompt.includes("Do not correct capitalization, punctuation"),
    "chat style is not over-corrected",
  );
  assert(
    prompt.includes("never depends on whether the viewer authored"),
    "provider output stays neutral between author and recipient",
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

Deno.test("server preserves authored interface-language text", () => {
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
    rewritten?.interfaceText === "What is you doing?",
    "server must restore the exact authored interface text",
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

function tamilCandidate(
  text: string,
  translation: string,
  roman: string,
  gloss: string,
) {
  const result = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "en",
      translation,
      interfaceText: text,
      explanation: null,
      confidence: null,
      tokens: [{ text: translation, gloss, roman, isContent: true }],
    }),
    text,
    "ta",
    "en",
  );
  assert(result !== null, `provider result for "${text}" should parse`);
  return result!;
}

Deno.test("one-word English echoed as Tamil is retried", () => {
  for (const word of ["yes", "hello", "thanks"]) {
    const echoed = tamilCandidate(word, word, word, word);
    assert(
      translationOutputNeedsRetry(echoed, word, "ta"),
      `untranslated "${word}" must be retried`,
    );
  }
});

Deno.test("one-word English translated into Tamil is accepted", () => {
  const cases: Array<[string, string, string, string]> = [
    ["yes", "ஆம்", "ām", "yes"],
    ["hello", "வணக்கம்", "vaṇakkam", "hello"],
    ["thanks", "நன்றி", "naṉṟi", "thanks"],
  ];
  for (const [word, translation, roman, gloss] of cases) {
    const translated = tamilCandidate(word, translation, roman, gloss);
    assert(
      translated.translation === translation,
      `"${word}" must keep its Tamil learning line`,
    );
    assert(
      !translationOutputNeedsRetry(translated, word, "ta"),
      `translated "${word}" must not be retried`,
    );
    assert(
      translated.tokens.length === 1,
      `"${word}" must keep its tappable token`,
    );
  }
});

Deno.test("echo retry ignores same-language and non-alphabetic input", () => {
  const unchanged = parseProviderResult(
    JSON.stringify({
      mode: "none",
      sourceLang: "ta",
      translation: "ஆம்",
      interfaceText: "yes",
      explanation: null,
      confidence: null,
      tokens: [],
    }),
    "ஆம்",
    "ta",
    "en",
  );
  assert(unchanged !== null, "same-language result should parse");
  assert(
    !translationOutputNeedsRetry(unchanged!, "ஆம்", "ta"),
    "mode=none is never an echo failure",
  );

  const brand = tamilCandidate("Google", "Google", "Google", "Google");
  assert(
    translationOutputNeedsRetry(brand, "Google", "ta"),
    "a short echoed word is retried once even when it may be a proper noun",
  );

  assert(!isShortAlphabeticText("blab.app/i/abc123"), "URLs are not retried");
  assert(!isShortAlphabeticText("see you at 8"), "digits are not retried");
  assert(!isShortAlphabeticText("thanks 🙏"), "emoji are not retried");
  assert(
    !isShortAlphabeticText("thanks so much for all of your help today"),
    "long messages are not retried",
  );
  assert(isShortAlphabeticText("thank you"), "short phrases are retried");
});

Deno.test("one-word translation keeps its tappable token despite padding", () => {
  const cases: Array<[string, string, string, string]> = [
    ["yes", "ஆம்", "aam", "yes"],
    ["hello", "வணக்கம்", "vaṇakkam", "greeting"],
    ["thanks", "நன்றி", "nandri", "thank you"],
  ];
  for (const [word, translation, roman, gloss] of cases) {
    const result = parseProviderResult(
      JSON.stringify({
        mode: "translation",
        sourceLang: "en",
        translation,
        interfaceText: word,
        explanation: null,
        confidence: null,
        tokens: [
          { text: translation, gloss, roman, isContent: true },
          { text: " ", gloss: null, roman: null, isContent: false },
        ],
      }),
      word,
      "ta",
      "en",
    );
    assert(result !== null, `"${word}" should parse`);
    assert(
      result?.translation === translation,
      `"${word}" must translate into Tamil`,
    );
    assert(
      result?.tokens.length === 1,
      `"${word}" must keep one tappable token despite the padding token`,
    );
  }
});

Deno.test("token padding repair never invents a matching list", () => {
  const mismatched = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "en",
      translation: "வணக்கம் நண்பா",
      interfaceText: "hello friend",
      explanation: null,
      confidence: null,
      tokens: [
        { text: "வணக்கம்", gloss: "hello", roman: "vaṇakkam", isContent: true },
        { text: " ", gloss: null, roman: null, isContent: false },
      ],
    }),
    "hello friend",
    "ta",
    "en",
  );
  assert(mismatched !== null, "translation should survive bad tokens");
  assert(
    mismatched?.translation === "வணக்கம் நண்பா",
    "learning line is preserved",
  );
  assert(
    mismatched?.tokens.length === 0,
    "a token list that drops words is discarded, not trimmed into shape",
  );
});

Deno.test("misdetected source on a short word is retried", () => {
  // The provider translates "sorry" correctly but labels the English input as
  // Tamil, so the unsafe-rewrite branch discards the translation.
  const collapsed = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "ta",
      translation: "மன்னிக்கவும்",
      interfaceText: "sorry",
      explanation: null,
      confidence: null,
      tokens: [
        {
          text: "மன்னிக்கவும்",
          gloss: "sorry",
          roman: "mannikkavum",
          isContent: true,
        },
      ],
    }),
    "sorry",
    "ta",
    "en",
  );
  assert(collapsed !== null, "the result should still parse");
  assert(collapsed?.mode === "none", "the rewrite is still collapsed");
  assert(
    collapsed?.translation === "sorry",
    "the authored line is still preserved on the collapsed result",
  );
  assert(
    translationOutputNeedsRetry(collapsed!, "sorry", "ta"),
    "a discarded short-word translation must be retried",
  );
});

Deno.test("a genuine same-language short message is not retried", () => {
  // Author really did write Tamil, so the provider returns it unchanged.
  const unchanged = parseProviderResult(
    JSON.stringify({
      mode: "none",
      sourceLang: "ta",
      translation: "நன்றி",
      interfaceText: "thanks",
      explanation: null,
      confidence: null,
      tokens: [],
    }),
    "நன்றி",
    "ta",
    "en",
  );
  assert(unchanged !== null, "same-language result should parse");
  assert(unchanged?.mode === "none", "mode stays none");
  assert(
    !translationOutputNeedsRetry(unchanged!, "நன்றி", "ta"),
    "writing in the learning language is not a failure",
  );
});

Deno.test("a real same-language correction is not retried", () => {
  const corrected = parseProviderResult(
    JSON.stringify({
      mode: "correction",
      sourceLang: "ta",
      translation: "நன்றி",
      interfaceText: "thanks",
      explanation: "Corrected the spelling.",
      confidence: "high",
      tokens: [{ text: "நன்றி", gloss: "thanks", roman: "nandri", isContent: true }],
    }),
    "நன்ரி",
    "ta",
    "en",
  );
  assert(corrected !== null, "correction should parse");
  assert(corrected?.mode === "correction", "mode stays correction");
  assert(
    !translationOutputNeedsRetry(corrected!, "நன்ரி", "ta"),
    "a bounded correction is a valid short-input result",
  );
});

Deno.test("collapse retry still respects the short-input guard", () => {
  const longInput = "sorry about missing the call yesterday afternoon";
  const collapsed = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "ta",
      translation: "மன்னிக்கவும் நேற்று",
      interfaceText: longInput,
      explanation: null,
      confidence: null,
      tokens: [],
    }),
    longInput,
    "ta",
    "en",
  );
  assert(collapsed !== null, "long collapsed result should parse");
  assert(
    !translationOutputNeedsRetry(collapsed!, longInput, "ta"),
    "the retry stays limited to short alphabetic input",
  );
});

Deno.test("echo retry guidance names the learning language", () => {
  const guidance = shortInputRetryGuidance("ta");
  assert(guidance.includes("Tamil"), "guidance names the target language");
  assert(guidance.includes("yes"), "guidance cites a one-word example");
  assert(
    guidance.includes("tokens"),
    "guidance keeps the tappable-word contract on the retry",
  );
});

async function withServer(
  handler: (request: Request) => Response | Promise<Response>,
  run: (url: string) => Promise<void>,
): Promise<void> {
  const controller = new AbortController();
  const server = Deno.serve(
    { port: 0, signal: controller.signal, onListen: () => {} },
    handler,
  );
  const port = (server.addr as Deno.NetAddr).port;
  try {
    await run(`http://127.0.0.1:${port}`);
  } finally {
    controller.abort();
    await server.finished;
  }
}

Deno.test("provider call that never answers fails as a timeout", async () => {
  await withServer(
    () => new Promise<Response>(() => {}),
    async (url) => {
      const started = Date.now();
      let thrown: unknown = null;
      try {
        await fetchProviderWithTimeout(url, { method: "POST" }, 250);
      } catch (error) {
        thrown = error;
      }
      assert(
        thrown instanceof ProviderTimeoutError,
        "a stalled provider must raise a timeout, not hang",
      );
      assert(
        Date.now() - started < 5_000,
        "the call must abort near its deadline",
      );
      assert(
        providerCallFailureReason(thrown) === "timeout",
        "a timeout is reported as timeout, not unreachable",
      );
    },
  );
});

Deno.test("provider that stalls mid-body fails as a timeout", async () => {
  await withServer(
    () =>
      new Response(
        new ReadableStream({
          start(controller) {
            controller.enqueue(new TextEncoder().encode('{"choices":'));
          },
        }),
        { headers: { "Content-Type": "application/json" } },
      ),
    async (url) => {
      let thrown: unknown = null;
      try {
        await fetchProviderWithTimeout(url, { method: "POST" }, 250);
      } catch (error) {
        thrown = error;
      }
      assert(
        thrown instanceof ProviderTimeoutError,
        "headers followed by a stalled body must also time out",
      );
    },
  );
});

Deno.test("provider answering in time returns its status and body", async () => {
  await withServer(
    () => new Response('{"ok":true}', { status: 200 }),
    async (url) => {
      const response = await fetchProviderWithTimeout(
        url,
        { method: "POST" },
        5_000,
      );
      assert(response.ok, "a prompt answer stays successful");
      assert(response.status === 200, "status is surfaced");
      assert(response.body === '{"ok":true}', "body is read in full");
    },
  );
});

Deno.test("provider error responses are surfaced, not swallowed", async () => {
  await withServer(
    () => new Response("upstream is busy", { status: 503 }),
    async (url) => {
      const response = await fetchProviderWithTimeout(
        url,
        { method: "POST" },
        5_000,
      );
      assert(!response.ok, "a 503 is not a success");
      assert(response.status === 503, "the caller can build http_503");
    },
  );
});

Deno.test("unreachable providers stay distinct from timeouts", async () => {
  let thrown: unknown = null;
  try {
    // Port 1 is reserved and refuses immediately, so this is a connection
    // failure rather than a deadline.
    await fetchProviderWithTimeout("http://127.0.0.1:1", { method: "POST" }, 5_000);
  } catch (error) {
    thrown = error;
  }
  assert(thrown !== null, "a refused connection still throws");
  assert(
    !(thrown instanceof ProviderTimeoutError),
    "a refused connection is not a timeout",
  );
  assert(
    providerCallFailureReason(thrown) === "unreachable",
    "a refused connection is reported as unreachable",
  );
});

Deno.test("provider deadline is bounded for two attempts plus a repair", () => {
  assert(PROVIDER_TIMEOUT_MS > 0, "a deadline is set");
  assert(
    PROVIDER_TIMEOUT_MS * 3 <= 60_000,
    "worst-case provider time stays inside the function budget",
  );
});

Deno.test("system prompt requires short inputs to be translated", () => {
  const prompt = systemPrompt("auto", "ta", "en");
  assert(
    prompt.includes("Short inputs are translated like any other."),
    "prompt carries the short-input rule",
  );
});
