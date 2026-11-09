import {
  correctedSource,
  explicitCorrections,
} from "./correction_provenance.ts";
const eq = (a: unknown, b: unknown) => {
  if (JSON.stringify(a) !== JSON.stringify(b)) {
    throw Error(JSON.stringify({ a, b }));
  }
};
Deno.test("explicit source validation repeated multiple unicode and invalid spans", () => {
  const source = "😀 Ich ist tired; sie ist busy.";
  const rows = [{ original: "ist", occurrence: 0, replacement: "bin" }];
  eq(
    correctedSource(source, explicitCorrections(source, rows)),
    "😀 Ich bin tired; sie ist busy.",
  );
  eq(
    explicitCorrections(source, [{
      original: "ist",
      occurrence: 1,
      replacement: "war",
    }])[0].start,
    source.lastIndexOf("ist"),
  );
  for (
    const raw of [
      [{ original: "missing", occurrence: 0, replacement: "x" }],
      [{ original: "ist", occurrence: 2, replacement: "x" }],
      [{ original: "ist", occurrence: -1, replacement: "x" }],
      [...rows, ...rows],
      [{ original: "\ud83d", occurrence: 0, replacement: "x" }],
      [{ original: "", occurrence: 0, replacement: "x" }],
    ]
  ) eq(explicitCorrections(source, raw), []);
  eq(
    correctedSource(
      "Ich ist und du ist",
      explicitCorrections("Ich ist und du ist", [{
        original: "ist",
        occurrence: 0,
        replacement: "bin",
      }, { original: "ist", occurrence: 1, replacement: "bist" }]),
    ),
    "Ich bin und du bist",
  );
});
