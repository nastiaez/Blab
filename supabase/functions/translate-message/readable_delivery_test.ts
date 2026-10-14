import {
  parseProviderResult,
  TRANSLATION_RESPONSE_FORMAT,
} from "./contract.ts";
import {
  enrichAcceptedWordHelp,
  knownLaneIsAuthoredOriginal,
  READABLE_TRANSLATION_RESPONSE_FORMAT,
  readableProviderMessages,
  restoreAcceptedReadable,
} from "./readable_delivery.ts";

Deno.test("readable schema removes only optional word metadata, preserving form choices", () => {
  const schema = READABLE_TRANSLATION_RESPONSE_FORMAT.json_schema.schema;
  if ("tokens" in schema.properties || schema.required.includes("tokens")) {
    throw new Error("metadata remains on the critical generation path");
  }
  const form = schema.properties.formAlternatives;
  if (
    "feminineTokens" in form.properties || "masculineTokens" in form.properties
  ) throw new Error("form metadata remains coupled");
  if (
    !form.required.includes("feminine") ||
    !form.required.includes("subjectIsViewer")
  ) throw new Error("form protections lost");
  if (
    !("tokens" in TRANSLATION_RESPONSE_FORMAT.json_schema.schema.properties)
  ) throw new Error("legacy contract mutated");
});
Deno.test("deferred metadata retains exact linked forms without inventing definitions", () => {
  const raw = JSON.stringify({
    mode: "translation",
    sourceLang: "en",
    translation: "Що ти робила вчора?",
    interfaceText: "What did you do yesterday?",
    explanation: null,
    confidence: null,
    formAlternatives: {
      before: "Що ти ",
      feminine: "робила",
      masculine: "робив",
      after: " вчора?",
      subjectName: "Bob",
      subjectIsViewer: false,
      suggestedForm: "feminine",
    },
  });
  const result = parseProviderResult(
    raw,
    "What did you do yesterday?",
    "uk",
    "en",
    undefined,
    true,
  );
  if (
    !result?.formAlternatives || result.tokens.length !== 0 ||
    result.formAlternatives.feminineTokens.length !== 0
  ) throw new Error("deferred form contract lost or invented metadata");
  const legacy = parseProviderResult(
    raw,
    "What did you do yesterday?",
    "uk",
    "en",
  );
  if (legacy?.formAlternatives !== null) {
    throw new Error("legacy complete metadata validation weakened");
  }
});
Deno.test("metadata resume preserves verified participant role without trusting provider role", () => {
  const saved = {
    mode: "translation",
    sourceLang: "en",
    translation: "Що ти робила вчора?",
    interfaceText: "What did you do yesterday?",
    explanation: null,
    confidence: null,
    formAlternatives: {
      before: "Що ти ",
      feminine: "робила",
      masculine: "робив",
      after: " вчора?",
      subjectName: "Bob",
      subjectIsViewer: true,
      suggestedForm: "feminine",
      subjectRole: "recipient",
    },
  };
  const resumed = restoreAcceptedReadable(
    saved,
    saved.interfaceText,
    "uk",
    "en",
  );
  if (resumed?.formAlternatives?.subjectRole !== "recipient") {
    throw new Error("verified role lost during metadata resume");
  }
  const provider = parseProviderResult(
    JSON.stringify(saved),
    saved.interfaceText,
    "uk",
    "en",
    undefined,
    true,
  );
  if (provider?.formAlternatives?.subjectRole !== undefined) {
    throw new Error("untrusted provider role accepted");
  }
});
Deno.test("readable prompt preserves source and meaning rules", () => {
  const messages = readableProviderMessages([{
    role: "system",
    content: "Preserve meaning and literal URLs.",
  }, { role: "user", content: "Hello" }]);
  if (
    !messages[0].content.startsWith("Preserve meaning and literal URLs.") ||
    messages[1].content !== "Hello" ||
    !messages[0].content.includes("Do not generate tokens")
  ) throw new Error("readable prompt corrupts safety/source contract");
});

Deno.test("only byte-identical authored text in its known language avoids a rewrite audit", () => {
  if (!knownLaneIsAuthoredOriginal("Hello!", "Hello!", "en", "en")) {
    throw new Error("unchanged source unnecessarily audited");
  }
  for (
    const [source, candidate, sourceLang, knownLang] of [
      ["Hello!", "Hello", "en", "en"],
      ["Hello", "Hi", "en", "en"],
      ["Hello", "Hello", "en", "de"],
      ["Hello\nBob", "Hello Bob", "en", "en"],
    ]
  ) {
    if (knownLaneIsAuthoredOriginal(source, candidate, sourceLang, knownLang)) {
      throw new Error("changed or unknown-language lane bypassed audit");
    }
  }
});

Deno.test("word-help failure leaves accepted text intact and retry never retranslates", async () => {
  const accepted = parseProviderResult(
    JSON.stringify({
      mode: "translation",
      sourceLang: "en",
      translation: "Hallo",
      interfaceText: "Hello",
      explanation: null,
      confidence: null,
      formAlternatives: null,
    }),
    "Hello",
    "de",
    "en",
    undefined,
    true,
  )!;
  const snapshot = JSON.stringify(accepted);
  let calls = 0;
  const failed = await enrichAcceptedWordHelp(
    accepted,
    async (sentence) => {
      calls++;
      if (sentence !== "Hallo") throw new Error("changed accepted text");
      return null;
    },
    "de",
    "en",
    "Hello",
  );
  if (failed !== null || JSON.stringify(accepted) !== snapshot) {
    throw new Error("metadata failure corrupted readable result");
  }
  const finished = await enrichAcceptedWordHelp(
    accepted,
    async (sentence) => {
      calls++;
      return [{ text: sentence, gloss: "hello", roman: null, isContent: true }];
    },
    "de",
    "en",
    "Hello",
  );
  if (
    calls !== 2 || finished?.translation !== "Hallo" ||
    finished.tokens.length !== 1
  ) throw new Error("metadata retry failed");
});
