import {
  anchoredCorrections,
  explicitCorrections,
  serializeGeneration,
} from "./correction_provenance.ts";
const assert = (x: unknown) => {
  if (!x) throw new Error("anchor assertion");
};
Deno.test("synthetic anchors: full target, repeats, reorder, multiword, malformed and overlap", () => {
  const source = "Ich ist tired.";
  const raw = [{
    original: "ist",
    occurrence: 0,
    replacement: "bin",
    targetAnchor: { text: "bin", occurrence: 0 },
  }];
  const resolve = (target: string, input: any[] = raw) =>
    anchoredCorrections(target, explicitCorrections(source, input), input);
  assert(resolve("Ich bin müde.")[0].targetAnchor?.start === 4);
  assert(
    resolve("bin, ich bin müde.", [{
      ...raw[0],
      targetAnchor: { text: "bin", occurrence: 1 },
    }])[0].targetAnchor?.start === 9,
  );
  assert(resolve("müde bin ich.")[0].targetAnchor?.start === 5);
  assert(
    resolve("I am tired.", [{
      ...raw[0],
      targetAnchor: { text: "am tired", occurrence: 0 },
    }])[0].targetAnchor?.text === "am tired",
  );
  for (
    const targetAnchor of [
      null,
      undefined,
      {},
      { text: "", occurrence: 0 },
      { text: "bin", occurrence: -1 },
      { text: "bin", occurrence: 0.5 },
      { text: "bin", occurrence: 999999999 },
      { text: "missing", occurrence: 0 },
    ]
  ) {
    assert(
      resolve("Ich bin müde.", [{ ...raw[0], targetAnchor }])[0]
        .targetAnchor === null,
    );
  }
  const input = [...raw, {
    original: "tired",
    occurrence: 0,
    replacement: "tiring",
    targetAnchor: { text: "bin müde", occurrence: 0 },
  }];
  assert(resolve("Ich bin müde.", input).every((c) => c.targetAnchor === null));
  const unicode = [{
    ...raw[0],
    targetAnchor: { text: "\ud83d", occurrence: 0 },
  }];
  assert(resolve("😀 bin", unicode)[0].targetAnchor === null);
  const envelope = {
    version: "a-v2",
    source,
    targetText: "Ich bin müde.",
    corrections: resolve("Ich bin müde."),
  };
  const saved = JSON.parse(
    JSON.stringify(
      serializeGeneration({ generationEnvelope: envelope, tokens: [] }),
    ),
  );
  assert(
    saved.formAlternatives.blabGenerationEnvelope.corrections[0].targetAnchor
      .text === "bin",
  );
});

Deno.test("synthetic protected literals cannot become corrections or target anchors", () => {
  for (
    const literal of ["@Alice", "#hello", "https://example.org/bin", "`bin`"]
  ) {
    const source = "See " + literal + " today";
    const start = source.indexOf(literal);
    const raw = [{ original: literal, occurrence: 0, replacement: "changed" }];
    assert(explicitCorrections(source, raw).length === 0);
    const c = {
      original: "ist",
      occurrence: 0,
      replacement: "bin",
      start: 0,
      end: 3,
    };
    const targetAnchor = {
      text: literal.includes("bin") ? "bin" : literal,
      occurrence: 0,
    };
    assert(
      anchoredCorrections(source, [c], [{ ...c, targetAnchor }])[0]
        .targetAnchor === null,
    );
    assert(start === 4);
  }
});
