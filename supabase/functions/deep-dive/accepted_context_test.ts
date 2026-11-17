import {
  acceptedContext,
  acceptedVariants,
  historicalEra,
} from "./accepted_context.ts";
import {
  DiveError,
  type DiveRequest,
  parseRequest,
  validateContext,
} from "./contract.ts";
function assert(x: unknown) {
  if (!x) throw new Error("assertion failed");
}
function rejects(fn: () => unknown) {
  try {
    fn();
  } catch (e) {
    assert(e instanceof DiveError);
    return;
  }
  throw new Error("expected rejection");
}
const r: DiveRequest = {
  messageId: "11111111-1111-4111-8111-111111111111",
  kind: "vocabulary",
  text: "Sono stanca.",
  start: 5,
  end: 11,
  targetLang: "it",
  knownLang: "uk",
  aidsEnabled: true,
  acceptedText: "Sono stanca.",
  sourceText: "I am tired.",
  languageRevision: 2,
};
const identity = {
  viewerId: "alice",
  senderId: "bob",
  source: "I am tired.",
  targetLang: "it",
  knownLang: "uk",
  revision: 2,
  sourceVersion: "hash",
};
const forms = {
  before: "Sono ",
  feminine: "stanca",
  masculine: "stanco",
  after: ".",
  subjectName: "Alice",
  subjectIsViewer: true,
};
const row = {
  viewer_id: "alice",
  status: "ready",
  language_revision: 2,
  source_version: "hash",
  learning_language: "it",
  primary_known_language: "uk",
  translation_text: "Sono stanca.",
  form_alternatives: forms,
  tokens: [],
  source_lang: "en",
  aid_mode: "translation",
};
Deno.test("saved alternative is accepted without changing the base or tokens", () => {
  const request = { ...r, text: "Sono stanco.", acceptedText: "Sono stanco." };
  const c = acceptedContext(request, identity, row, "prepared");
  assert(
    c.translation === "Sono stanco." && c.baseTranslation === "Sono stanca.",
  );
  validateContext(request, c);
});
Deno.test("invented variants, corrupt forms and cross-viewer package rejected", () => {
  rejects(() =>
    acceptedContext(
      { ...r, acceptedText: "Sono inventata." },
      identity,
      row,
      "prepared",
    )
  );
  rejects(() =>
    acceptedContext(r, identity, { ...row, viewer_id: "bob" }, "prepared")
  );
  rejects(() =>
    acceptedContext(
      { ...r, text: "Sono stanco.", acceptedText: "Sono stanco." },
      identity,
      { ...row, form_alternatives: { ...forms, subjectIsViewer: undefined } },
      "prepared",
    )
  );
});
Deno.test("legacy row must bind exact source hash, known language and historical target", () => {
  const legacy = {
    ...row,
    target_lang: "it",
    interface_lang: "uk",
    source_hash: "hash",
  };
  validateContext(r, acceptedContext(r, identity, legacy, "legacy"));
  for (
    const patch of [{ source_hash: "stale" }, { interface_lang: "es" }, {
      target_lang: "de",
    }]
  ) {
    rejects(() =>
      acceptedContext(r, identity, { ...legacy, ...patch }, "legacy")
    );
  }
});
Deno.test("edits and historical revision mismatch cannot reuse accepted context", () => {
  rejects(() =>
    acceptedContext(
      { ...r, sourceText: "I am happy." },
      identity,
      row,
      "prepared",
    )
  );
  rejects(() =>
    acceptedContext({ ...r, languageRevision: 3 }, identity, row, "prepared")
  );
  rejects(() =>
    acceptedContext(r, identity, { ...row, language_revision: 3 }, "prepared")
  );
});
Deno.test("stored list and token-carried forms accepted, no cross-subject recombination", () => {
  const other = {
    ...forms,
    before: "Sei ",
    feminine: "pronta",
    masculine: "pronto",
  };
  const variants = acceptedVariants({
    ...row,
    form_alternatives: [forms, other],
  });
  assert(
    variants.includes("Sei pronto.") && !variants.includes("Sono pronto."),
  );
  assert(
    acceptedVariants({
      ...row,
      form_alternatives: null,
      tokens: [{ formAlternatives: forms }],
    }).includes("Sono stanco."),
  );
});
Deno.test("historical era uses message date not latest revision or requested language", () => {
  const rows = [{
    revision: 1,
    learning_language: "it",
    created_at: "2026-01-01T00:00:00Z",
  }, {
    revision: 2,
    learning_language: "de",
    created_at: "2026-02-01T00:00:00Z",
  }, {
    revision: 3,
    learning_language: "es",
    created_at: "2026-03-01T00:00:00Z",
  }];
  const era = historicalEra(rows, "2026-02-15T00:00:00Z", "fr", 3);
  assert(era.language === "de" && era.revision === 2);
});
Deno.test("a-v1 genuine saved source corrections work, summary-only legacy cannot invent spans", () => {
  const request = {
    ...r,
    kind: "correction" as const,
    text: "Ich bist hier",
    sourceText: "Ich bist hier",
    acceptedText: "Ich bin hier",
    start: 4,
    end: 8,
    targetLang: "de",
    replacement: "bin",
  };
  const c = {
    ...identity,
    source: request.text,
    targetLang: "de",
    sourceLang: "de",
    aidMode: "correction",
    senderId: "alice",
    translation: "Ich bin hier",
    tokens: [{
      blabAuthoredCorrection: {
        version: "a-v1",
        source: request.text,
        correctionText: "Ich bin hier",
        corrections: [{
          original: "bist",
          occurrence: 0,
          start: 4,
          end: 8,
          replacement: "bin",
        }],
      },
    }],
  };
  validateContext(request, c);
  rejects(() => validateContext(request, { ...c, tokens: [] }));
  rejects(() =>
    validateContext(request, {
      ...c,
      tokens: [{
        blabAuthoredCorrection: {
          ...c.tokens[0].blabAuthoredCorrection,
          correctionText: "invented",
        },
      }],
    })
  );
});
Deno.test("new request pins reject invalid types and unbounded context", () => {
  for (
    const patch of [{ languageRevision: 0 }, { languageRevision: 1.2 }, {
      sourceText: 12,
    }, { acceptedText: "x".repeat(8001) }]
  ) rejects(() => parseRequest({ ...r, ...patch }));
});
