import { privateGroupResult } from "../prepare-message-jobs/group_outputs.ts";
import {
  explicitCorrections,
  serializeGeneration,
} from "./correction_provenance.ts";
import {
  commitGroupViewers,
  commitViewers,
} from "../prepare-message-jobs/commit_viewers.ts";
const assert = (ok: unknown) => {
  if (!ok) throw Error("assertion failed");
};
Deno.test("capitalization punctuation and spacing alone never create source marks", () => {
  for (
    const [original, replacement] of [["haus", "Haus"], ["hello!", "Hello"], [
      "foo bar",
      "foobar",
    ]]
  ) {
    assert(
      explicitCorrections(original, [{ original, replacement, occurrence: 0 }])
        .length === 0,
    );
  }
  assert(
    explicitCorrections("Ich ist tired", [{
      original: "ist",
      replacement: "bin",
      occurrence: 0,
    }]).length === 1,
  );
});
Deno.test("direct/group serialization retains independent generation identity without token metadata", async () => {
  const envelope = { version: "a-v1", source: "Ich ist tired." };
  const result = {
    translation: "Ich bin müde.",
    tokens: [],
    formAlternatives: null,
    generationEnvelope: envelope,
  };
  const stored = serializeGeneration(result) as any;
  assert(
    stored.formAlternatives.blabGenerationEnvelope.source === envelope.source,
  );
  assert(stored.tokens.length === 0);
  const seen: any[] = [];
  const rpc = (name: string, args: any) => {
    seen.push(args);
    return Promise.resolve({
      error: null,
      data: name === "complete_group_translation_viewers"
        ? [{ jobId: "j", error: null }]
        : true,
    });
  };
  await commitViewers(rpc, [{ jobId: "j", lease: "l", result }]);
  await commitGroupViewers(rpc, [{ jobId: "j", lease: "l", result }]);
  assert(
    seen[0].p_results[0].result.formAlternatives.blabGenerationEnvelope
      .version === "a-v1",
  );
  assert(
    seen[1].p_entries[0].result.formAlternatives.blabGenerationEnvelope
      .version === "a-v1",
  );
});
Deno.test("legacy serializers do not introduce generation metadata or rewrite history", () => {
  const old = { translation: "old", tokens: [], formAlternatives: null };
  assert(serializeGeneration(old) === old);
});
Deno.test("existing SQL exposes no-form independent envelope durability gap", async () => {
  const sql = await Deno.readTextFile(
    new URL(
      "../../migrations/20261016000002_translation_storage_acceptance.sql",
      import.meta.url,
    ),
  );
  // This is a blocker assertion, not proof of production round-trip support.
  assert(sql.includes("then f:=null; end if;"));
  assert(!sql.includes("blabGenerationEnvelope"));
});

Deno.test("new group recipient retains full learning translation without private source corrections", () => {
  const raw = {
    translation: "Ich bin müde.",
    interfaceText: "I am tired.",
    sourceLang: "de",
    mode: "correction" as const,
    explanation: "Use bin.",
    confidence: "high" as const,
    tokens: [{
      blabAuthoredCorrection: { version: "a-v1", source: "Ich ist tired." },
    }],
    formAlternatives: null,
    generationEnvelope: { version: "a-v1" as const, source: "Ich ist tired." },
  };
  const result = privateGroupResult({
    key: "v",
    messageId: "m",
    sourceHash: "s",
    text: "Ich ist tired.",
    targetLang: "de",
    interfaceLang: "en",
    formContext: { group: true, messageAuthor: "partner" },
  }, raw);
  assert(result.translation === "Ich bin müde.");
  assert(
    result.mode === "none" && result.confidence === null &&
      result.explanation === null,
  );
  assert(!result.tokens.some((t: any) => t.blabAuthoredCorrection));
});

Deno.test("malformed top-level generation presence survives serialization", () => {
  for (const generationEnvelope of [null, false, 0, "", "bad", [], {}]) {
    const saved = serializeGeneration({
      generationEnvelope,
      tokens: [],
      formAlternatives: null,
    });
    assert(Object.hasOwn(saved.formAlternatives!, "blabGenerationEnvelope"));
    assert(
      JSON.stringify((saved.formAlternatives as any).blabGenerationEnvelope) ===
        "{}",
    );
  }
});
