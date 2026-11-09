import { generateGroupOutputs } from "../prepare-message-jobs/group_outputs.ts";
import { GENERATION_POLICY_VERSION, SINGLE_CALL_POLICY } from "./rulebook.ts";
Deno.test("authored provenance changes generation keys but preserves completed history without writes", async () => {
  if (
    !GENERATION_POLICY_VERSION.startsWith("authored-provenance-") ||
    SINGLE_CALL_POLICY.contractVersion !== "minimal-source-anchor-v11"
  ) throw Error("history contract changed");
  const viewer = {
    key: "v",
    messageId: "m",
    sourceHash: "s",
    text: "Ich ist tired.",
    targetLang: "de",
    interfaceLang: "en",
    formContext: { messageAuthor: "viewer", group: true },
  };
  const old = {
    translation: "Ich bin müde.",
    interfaceText: "I am tired.",
    sourceLang: "de",
    mode: "correction" as const,
    explanation: "Existing history explanation",
    confidence: "high" as const,
    tokens: [],
    formAlternatives: null,
  };
  const result = await generateGroupOutputs([viewer], {
    cached: async () => structuredClone(old),
    generate: async () => {
      throw Error("history regenerated");
    },
    save: async () => {
      throw Error("history overwritten");
    },
    renew: async () => {
      throw Error("history generation lease");
    },
  });
  if (JSON.stringify(result.v) !== JSON.stringify(old)) {
    throw Error("completed history changed");
  }
});
