import {
  anchoredCorrections,
  correctedSource,
  explicitCorrections,
  identicalWholeWordEdges,
} from "./correction_provenance.ts";
import { generateMessageOnce } from "./single_call.ts";
import { serializeGeneration } from "./correction_provenance.ts";
const eq = (a: unknown, b: unknown) => {
  if (JSON.stringify(a) !== JSON.stringify(b)) {
    throw Error(JSON.stringify({ a, b }));
  }
};
Deno.test("exact whole words not inflections capitalization punctuation apostrophes or empty edits", () => {
  for (
    const [a, b, want] of [
      ["Ich ist", "Ich bin", [4, 0]],
      ["ist hier", "bin hier", [0, 5]],
      ["Ich ist hier", "Ich bin hier", [4, 5]],
      ["unhappy", "unfair", [0, 0]],
      ["bist", "ist", [0, 0]],
      ["der Mann", "die Mann", [0, 5]],
      ["Ich ist", "ich bin", [0, 0]],
      ["foo-bar", "foo-baz", [0, 0]],
      ["foo bar", "foo bars", [4, 0]],
      ["a", "a b", [0, 0]],
      ["can’t", "can", [0, 0]],
    ] as const
  ) eq(identicalWholeWordEdges(a, b), want);
});
Deno.test("repeat source/target occurrences offsets full correction unchanged; uncertain mapping retained", () => {
  const source = "ist Ich ist und du ist hier",
    target = "bin Ich bin und du bist hier";
  const raw = [{
    original: "Ich ist",
    replacement: "Ich bin",
    occurrence: 0,
    targetAnchor: { text: "Ich bin", occurrence: 0 },
  }, {
    original: "du ist hier",
    replacement: "du bist hier",
    occurrence: 0,
    targetAnchor: { text: "du bist hier", occurrence: 0 },
  }];
  const before = explicitCorrections(source, raw),
    out = anchoredCorrections(target, before, raw, source);
  eq(
    out.map(
      (c) => [
        c.original,
        c.replacement,
        c.occurrence,
        c.start,
        c.targetAnchor?.occurrence,
      ],
    ),
    [["ist", "bin", 1, 8, 1], ["ist", "bist", 2, 19, 0]],
  );
  eq(correctedSource(source, before), correctedSource(source, out));
  for (const text of ["you are", "hier bist du"]) {
    const r = [{ ...raw[0], targetAnchor: { text, occurrence: 0 } }];
    const o = anchoredCorrections(
      text,
      explicitCorrections(source, r),
      r,
      source,
    );
    eq(o[0].original, "Ich ist");
    eq(o[0].targetAnchor?.text, text);
  }
  const p = "See @Alice ist";
  const r = [{
    original: "@Alice ist",
    replacement: "@Alice bin",
    occurrence: 0,
    targetAnchor: { text: "@Alice bin", occurrence: 0 },
  }];
  eq(explicitCorrections(p, r), []);
});
const root = Deno.env.get("BLA28_TRIM_EVIDENCE");
if (root) {
  Deno.test("all six actual18780 raw responses offline through unchanged production generator", async () => {
    const rows = [];
    for (let n = 1; n <= 6; n++) {
      const r = JSON.parse(
        await Deno.readTextFile(
          "qa-artifacts/bla28-18780-live/call-" + n + ".json",
        ),
      );
      const generated = await generateMessageOnce(r.viewers, {
        provider: "openai",
        apiKey: "offline-no-key",
        model: "offline",
        useOpenRouterProviderPolicy: false,
      }, async () => new Response(JSON.stringify(r.raw)));
      for (const [k, v] of Object.entries(generated)) {
        eq(v.translation, r.parsed[k].translation);
        eq(v.interfaceText, r.parsed[k].interfaceText);
        eq(v.explanation, r.parsed[k].explanation);
        const meta = (v.tokens[0] as any).blabAuthoredCorrection;
        if (n === 2 || n === 5) {
          eq(
            meta.corrections.map((
              c: any,
            ) => [
              c.original,
              c.replacement,
              c.occurrence,
              c.targetAnchor.text,
            ]),
            [["ist", "bin", 0, "bin"], ["ist", "bist", 1, "bist"]],
          );
        }
      }
      rows.push({
        id: n,
        arm: "live18780-offline-trim",
        text: r.text,
        viewers: r.viewers,
        outputs: Object.fromEntries(
          Object.entries(generated).map((
            [k, v],
          ) => [k, serializeGeneration(v)]),
        ),
      });
    }
    await Deno.writeTextFile(
      root + "/backend-after.json",
      JSON.stringify({ calls: 6, rows }, null, 2),
    );
  });
}
Deno.test("narrowing cannot conceal original anchor overlap or split surrogates", () => {
  const source = "A ist X", target = "A bin";
  const raw = [{
    original: "A ist",
    replacement: "A bin",
    occurrence: 0,
    targetAnchor: { text: "A bin", occurrence: 0 },
  }, {
    original: "X",
    replacement: "A",
    occurrence: 0,
    targetAnchor: { text: "A", occurrence: 0 },
  }];
  const out = anchoredCorrections(
    target,
    explicitCorrections(source, raw),
    raw,
    source,
  );
  eq(out.map((c) => c.targetAnchor), [null, null]);
  eq(
    explicitCorrections("😀 ist", [{
      original: String.fromCharCode(0xD83D),
      replacement: "X",
      occurrence: 0,
    }]),
    [],
  );
  const emoji = "😀 Ich ist";
  const r = [{
    original: "Ich ist",
    replacement: "Ich bin",
    occurrence: 0,
    targetAnchor: { text: "Ich bin", occurrence: 0 },
  }];
  const e = anchoredCorrections(
    "😀 Ich bin",
    explicitCorrections(emoji, r),
    r,
    emoji,
  )[0];
  eq([e.start, e.end, e.original, e.targetAnchor?.start], [7, 10, "ist", 7]);
});
