import { compactPlan, expandCompactResponse } from "./compact_request.ts";
import type { PreparedViewer } from "./single_call.ts";
const assert = (ok: unknown, detail: string) => {
  if (!ok) throw new Error(detail);
};
for (const acceptance of ["strict", "nonempty"] as const) {
  for (
    const scenario of [
      {
        label: "whitespace-equivalent retains authored spacing",
        original: "Ich  bin hier.",
        output: "Ich bin hier.",
        expected: "Ich  bin hier.",
        source: "de",
        target: "de",
        mode: "none",
      },
      {
        label: "BLA28 exact original whole message under none",
        original: "Ich habe eine Frage - möchtest du meine Fehler sehen oder ist es distracting for you?",
        output: "Ich habe eine Frage – möchtest du meine Fehler sehen, oder lenkt dich das ab?",
        source: "de",
        target: "de",
        mode: "none",
      },
      {
        label: "BLA28 additional beautiful reproduction under none",
        original: "du bist beautiful",
        output: "Du bist wunderschön.",
        source: "de",
        target: "de",
        mode: "none",
      },
      {
        label: "mixed language",
        original: "Ich bin tired, aber nicht krank.",
        output: "Ich bin müde, aber nicht krank.",
        source: "de",
        target: "de",
        mode: "none",
      },
      {
        label: "silent mechanical cleanup",
        original: "ich bin hier",
        output: "Ich bin hier.",
        source: "de",
        target: "de",
        mode: "none",
      },
      {
        label: "real source correction",
        original: "Ich ist hier.",
        output: "Ich bin hier.",
        source: "de",
        target: "de",
        mode: "correction",
      },
      {
        label: "unchanged expressive input",
        original: "Jaaaa!",
        output: "Jaaaa!",
        source: "de",
        target: "de",
        mode: "none",
      },
      {
        label: "unsupported source",
        original: "未知",
        output: "未知",
        source: "other",
        target: "de",
        mode: "translation",
      },
    ]
  ) {
    Deno.test(
      acceptance +
        " preserves returned output without inventing correction mode: " +
        scenario.label,
      () => {
        const viewers: PreparedViewer[] = [
          {
            key: "alice",
            messageId: "synthetic",
            sourceHash: "synthetic",
            text: scenario.original,
            targetLang: scenario.target,
            interfaceLang: "en",
            formContext: { messageAuthor: "viewer" },
          },
          {
            key: "bob",
            messageId: "synthetic",
            sourceHash: "synthetic",
            text: scenario.original,
            targetLang: "es",
            interfaceLang: "uk",
            formContext: { messageAuthor: "partner" },
          },
        ];
        const p = compactPlan(viewers);
        const raw = {
          sentences: p.requested.sentences.map((s) => ({
            id: s.id,
            text: s.id === p.bindings.alice.sentence
              ? scenario.output
              : "independent " + s.id,
            sourceLang: scenario.source,
            mode: scenario.mode,
            confidence: scenario.mode === "correction" ? "high" : null,
            forms: null,
          })),
          help: p.requested.help.map((h) => ({
            id: h.id,
            tokens: [],
            explanation: scenario.mode === "correction"
              ? "Subject agreement."
              : null,
            feminineTokens: [],
            masculineTokens: [],
          })),
        };
        const before = JSON.stringify(raw);
        const result = expandCompactResponse(raw, viewers, p, acceptance);
        assert(
          result.alice.translation ===
            ("expected" in scenario ? scenario.expected : scenario.output),
          "valid provider output lost: " + JSON.stringify(result.alice),
        );
        assert(
          result.alice.mode === scenario.mode,
          "mode must not be inferred from changed text",
        );
        assert(
          result.bob.translation ===
            raw.sentences.find((s) => s.id === p.bindings.bob.sentence)!.text,
          "asymmetric Bob output leaked",
        );
        assert(
          JSON.stringify(raw) === before,
          "retained provider receipt mutated",
        );
      },
    );
  }
}
