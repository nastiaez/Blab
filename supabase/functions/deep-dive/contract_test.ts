import {
  analysisMessages,
  type Context,
  DiveError,
  type DiveRequest,
  parseAnalysis,
  parseRequest,
  validateContext,
} from "./contract.ts";
function assert(x: unknown) {
  if (!x) throw new Error("assertion failed");
}
function rejects(fn: () => unknown, code: string) {
  try {
    fn();
  } catch (e) {
    assert(e instanceof DiveError && e.code === code);
    return;
  }
  throw new Error("expected " + code);
}
const r: DiveRequest = {
  messageId: "11111111-1111-4111-8111-111111111111",
  kind: "vocabulary",
  text: "Ich bin hier",
  start: 4,
  end: 7,
  targetLang: "de",
  knownLang: "uk",
  aidsEnabled: true,
};
const c: Context = {
  viewerId: "a",
  senderId: "a",
  sourceLang: "de",
  aidMode: "correction",
  source: "Ich bist hier",
  translation: r.text,
  targetLang: "de",
  knownLang: "uk",
  revision: 1,
  sourceVersion: "abc",
  tokens: [{
    blabAuthoredCorrection: {
      version: "a-v2",
      source: "Ich bist hier",
      targetText: r.text,
      correctionText: r.text,
      corrections: [{
        original: "bist",
        occurrence: 0,
        replacement: "bin",
        targetAnchor: { text: "bin", occurrence: 0 },
      }],
    },
  }],
};
Deno.test("valid vocabulary and genuine per-mistake correction", () => {
  validateContext(parseRequest(r), c);
  validateContext({
    ...r,
    kind: "correction",
    text: c.source,
    start: 4,
    end: 8,
    replacement: "bin",
  }, c);
});
Deno.test("learning aids off rejected before generation", () =>
  rejects(
    () => parseRequest({ ...r, aidsEnabled: false }),
    "learning_aids_off",
  ));
Deno.test("missing aids flag fails closed", () =>
  rejects(
    () => parseRequest({ ...r, aidsEnabled: undefined }),
    "invalid_request",
  ));
Deno.test("invalid spans and languages rejected", () => {
  for (
    const patch of [
      { start: -1 },
      { end: 99 },
      { start: 1.5 },
      { targetLang: "xx" },
      { knownLang: "xx" },
      { kind: "other" },
    ]
  ) rejects(() => parseRequest({ ...r, ...patch }), "invalid_request");
});
Deno.test("UTF16 split rejected", () =>
  rejects(
    () => parseRequest({ ...r, text: "😀abc", start: 1, end: 3 }),
    "invalid_span",
  ));
Deno.test("stale sentence rejected", () =>
  rejects(() => validateContext({ ...r, text: "invented" }, c), "stale_text"));
Deno.test("viewer known language must be current", () =>
  rejects(
    () => validateContext({ ...r, knownLang: "en" }, c),
    "preferences_changed",
  ));
Deno.test("recipient correction fails closed", () =>
  rejects(
    () =>
      validateContext({ ...r, kind: "correction" }, { ...c, viewerId: "b" }),
    "correction_not_authorized",
  ));
Deno.test("no provenance cannot fabricate corrections", () =>
  rejects(
    () =>
      validateContext({ ...r, kind: "correction", text: c.source }, {
        ...c,
        tokens: [],
      }),
    "correction_provenance_unavailable",
  ));
Deno.test("replacement and exact source span validated", () =>
  rejects(
    () =>
      validateContext({
        ...r,
        kind: "correction",
        text: c.source,
        start: 4,
        end: 8,
        replacement: "sind",
      }, c),
    "invalid_correction_span",
  ));
Deno.test("whole-message summary without mistake explanation rejected", () =>
  rejects(
    () => parseAnalysis({ meaning: "meaning" }, "correction"),
    "invalid_analysis",
  ));
Deno.test("malformed optional enrichment dropped", () => {
  const a = parseAnalysis({
    meaning: "meaning",
    grammarTable: [{ label: 3, value: "bad" }],
    examples: [{}],
  }, "vocabulary");
  assert(!a.grammarTable && !a.examples);
});
Deno.test("dynamic languages independently resolved, no interface target", () => {
  assert(analysisMessages(r, c)[0].content.includes("Ukrainian"));
  assert(
    analysisMessages({ ...r, targetLang: "es", knownLang: "fr" }, {
      ...c,
      targetLang: "es",
      knownLang: "fr",
    })[0].content.includes("French"),
  );
});

Deno.test("recipient genuine correction uses immutable matched-at-send flag", () => {
  validateContext({
    ...r,
    kind: "correction",
    text: c.source,
    start: 4,
    end: 8,
    replacement: "bin",
  }, { ...c, viewerId: "b", languagesMatchedAtSend: true });
  rejects(
    () =>
      validateContext({
        ...r,
        kind: "correction",
        text: c.source,
        start: 4,
        end: 8,
        replacement: "bin",
      }, { ...c, viewerId: "b", languagesMatchedAtSend: false }),
    "correction_not_authorized",
  );
});
Deno.test("translated source never becomes an authored learning-language mistake", () => {
  rejects(
    () =>
      validateContext({
        ...r,
        kind: "correction",
        text: c.source,
        start: 4,
        end: 8,
        replacement: "bin",
      }, { ...c, sourceLang: "en" }),
    "correction_not_authorized",
  );
});
Deno.test("gender palette uses enum, optional learning-language grammar header is validated", () => {
  const parsed = parseAnalysis({
    meaning: "meaning",
    gender: "neuter",
    grammarLabel: "label",
    grammarHeaders: { label: "number", value: "form" },
  }, "vocabulary");
  assert(parsed.gender === "neuter" && parsed.grammarHeaders?.value === "form");
  assert(
    !parseAnalysis({ meaning: "meaning", gender: "arbitrary" }, "vocabulary")
      .gender,
  );
});

Deno.test("linked expression keeps component selection and context pins", () => {
  const text = "Ich stehe um sieben auf.";
  for (const word of ["stehe", "auf"]) {
    const start = text.indexOf(word);
    const request = parseRequest({
      ...r,
      text,
      start,
      end: start + word.length,
      sourceText: text,
      acceptedText: text,
      languageRevision: 1,
    });
    const context = { ...c, source: text, translation: text, tokens: [] };
    const before = JSON.stringify({ request, context });
    validateContext(request, context);
    const messages = analysisMessages(request, context);
    const data = JSON.parse(messages[1].content);
    assert(messages.length === 2);
    assert(data.selection === word && data.selectionText === text);
    assert(data.start === start && data.end === start + word.length);
    assert(data.acceptedTranslation === text && data.source === text);
    assert(data.kind === "vocabulary" && data.replacement === undefined);
    assert(
      messages[0].content.includes(
        "Related parts of an expression may be separated",
      ),
    );
    assert(
      messages[0].content.includes("Do not expand or replace the selection"),
    );
    assert(JSON.stringify({ request, context }) === before);
    rejects(
      () => validateContext({ ...request, acceptedText: text + "!" }, context),
      "stale_context",
    );
    rejects(
      () => validateContext({ ...request, languageRevision: 2 }, context),
      "stale_context",
    );
    rejects(
      () => validateContext({ ...request, sourceText: "other" }, context),
      "stale_context",
    );
  }
});

for (
  const [lang, word] of [["de", "stehe"], ["hi", "किताब"], ["ta", "புத்தகம்"], [
    "ko",
    "책",
  ]]
) {
  Deno.test(
    lang + " repeated occurrence retains UTF16 context after emoji",
    () => {
      const text = "😀 " + word + ", " + word + "!";
      const context = {
        ...c,
        source: text,
        translation: text,
        targetLang: lang,
        tokens: [],
      };
      const starts = [text.indexOf(word), text.lastIndexOf(word)];
      assert(starts[0] === 3 && starts[1] > starts[0]);
      const payloads = starts.map((start) => {
        const request = parseRequest({
          ...r,
          text,
          targetLang: lang,
          start,
          end: start + word.length,
        });
        validateContext(request, context);
        const data = JSON.parse(analysisMessages(request, context)[1].content);
        assert(data.selection === word && data.selectionText === text);
        assert(data.selectionText.slice(data.start, data.end) === word);
        assert(data.start === start && data.end === start + word.length);
        assert(data.acceptedTranslation === text);
        return data;
      });
      assert(payloads[0].start !== payloads[1].start);
      rejects(
        () => parseRequest({ ...r, text, start: 1, end: 2 }),
        "invalid_span",
      );
      rejects(
        () => parseRequest({ ...r, text, start: 0, end: 1 }),
        "invalid_span",
      );
    },
  );
}

Deno.test("correct and foreign vocabulary never acquire correction authority", () => {
  for (const text of ["Ich stehe um sieben auf.", "Ich sage hello."]) {
    const word = text.includes("hello") ? "hello" : "stehe";
    const start = text.indexOf(word);
    const context = { ...c, source: text, translation: text, tokens: [] };
    const request = { ...r, text, start, end: start + word.length };
    validateContext(request, context);
    const messages = analysisMessages(request, context);
    assert(JSON.parse(messages[1].content).kind === "vocabulary");
    assert(
      messages[0].content.includes(
        "correctly written foreign word as an authored error",
      ),
    );
    rejects(
      () =>
        validateContext({
          ...request,
          kind: "correction",
          replacement: "other",
        }, context),
      "correction_provenance_unavailable",
    );
  }
});

Deno.test("sentence grammar stays within saved selected mistake explanation", () => {
  const request: DiveRequest = {
    ...r,
    kind: "correction",
    text: c.source,
    start: 4,
    end: 8,
    replacement: "bin",
  };
  validateContext(request, c);
  const messages = analysisMessages(request, c);
  const data = JSON.parse(messages[1].content);
  assert(data.selection === "bist" && data.replacement === "bin");
  assert(
    data.selectionText === c.source &&
      data.acceptedTranslation === c.translation,
  );
  assert(data.start === 4 && data.end === 8);
  assert(
    messages[0].content.includes(
      "relevant sentence grammar or word-order relationship",
    ),
  );
  assert(
    messages[0].content.includes(
      "existing per-mistake slot, not a whole-message summary",
    ),
  );
  rejects(
    () =>
      parseAnalysis(
        { meaning: "meaning", summary: "invented summary" },
        "correction",
      ),
    "invalid_analysis",
  );
});

Deno.test("short mode is additive, exact occurrence data and strict meaning only", () => {
  const short = parseRequest({ ...r, mode: "short" });
  validateContext(short, c);
  const messages = analysisMessages(short, c);
  assert(messages[0].content.includes('Return only JSON: {"meaning":string}.'));
  assert(messages[0].content.includes("Primary Known Language: Ukrainian."));
  assert(
    JSON.stringify(JSON.parse(messages[1].content)) ===
      JSON.stringify({
        acceptedTranslation: c.translation,
        selectionText: r.text,
        start: 4,
        end: 7,
      }),
  );
  assert(
    parseAnalysis({ meaning: "бути" }, "vocabulary", "short").meaning ===
      "бути",
  );
  for (
    const value of [
      { meaning: "" },
      { meaning: "x", explanation: "extra" },
      { meaning: "x", examples: [] },
      { meaning: "x".repeat(1001) },
      { meaning: 2 },
    ]
  ) {
    rejects(
      () => parseAnalysis(value, "vocabulary", "short"),
      "invalid_analysis",
    );
  }
  rejects(
    () => parseRequest({ ...r, mode: "short", kind: "correction" }),
    "invalid_request",
  );
  rejects(() => parseRequest({ ...r, mode: "unknown" }), "invalid_request");
  assert(
    JSON.stringify(analysisMessages(r, c)) ===
      JSON.stringify(analysisMessages({ ...r, mode: "full" }, c)),
  );
  assert(
    parseAnalysis({ meaning: "x", explanation: "retained" }, "vocabulary")
      .explanation === "retained",
  );
});
