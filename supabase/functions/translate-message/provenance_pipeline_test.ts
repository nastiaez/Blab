import { generateMessageOnce, singleCallRequest } from "./single_call.ts";
import { compactPlan } from "./compact_request.ts";
Deno.test("mixed genuine error retains complete translation and correction-only provenance", async () => {
  const viewers = [{
    key: "v0",
    messageId: "synthetic",
    sourceHash: "synthetic",
    text: "Ich ist tired.",
    targetLang: "de",
    interfaceLang: "en",
    formContext: { messageAuthor: "viewer" },
  }];
  const p = compactPlan(viewers);
  const content = {
    sentences: p.requested.sentences.map((s) => ({
      id: s.id,
      sourceLang: "de",
      mode: "correction",
      text: s.language === "German" ? "Ich bin müde." : "I am tired.",
      confidence: "high",
      forms: null,
      corrections: [{ original: "ist", occurrence: 0, replacement: "bin" }],
      correctionText: "Ich bin tired.",
    })),
    help: p.requested.help.map((h) => ({
      id: h.id,
      explanation: "Use bin with ich.",
      tokens: [],
      feminineTokens: [],
      masculineTokens: [],
    })),
  };
  const r = await generateMessageOnce(
    viewers,
    { provider: "openai", apiKey: "test", model: "test" } as any,
    async () =>
      new Response(
        JSON.stringify({
          choices: [{ message: { content: JSON.stringify(content) } }],
        }),
      ),
  );
  if (r.v0.translation !== "Ich bin müde.") throw Error("translation lost");
  const meta = r.v0.tokens.find((t: any) => t.blabAuthoredCorrection) as any;
  if (meta?.blabAuthoredCorrection?.correctionText !== "Ich bin tired.") {
    throw Error("provenance lost");
  }
  const schema = JSON.stringify(singleCallRequest(viewers).response_format);
  if (!schema.includes("corrections") && !schema.includes("correctionText")) {
    throw Error("missing schema");
  }
});

Deno.test("omitted provenance never falls back to diffing a complete translation", async () => {
  const viewers = [{
    key: "v0",
    messageId: "m",
    sourceHash: "s",
    text: "Ich ist tired.",
    targetLang: "de",
    interfaceLang: "en",
  }];
  const p = compactPlan(viewers);
  const content = {
    sentences: p.requested.sentences.map((s) => ({
      id: s.id,
      sourceLang: "de",
      mode: "correction",
      text: s.language === "German" ? "Ich bin müde." : "I am tired.",
      confidence: "high",
      forms: null,
    })),
    help: p.requested.help.map((h) => ({
      id: h.id,
      explanation: "Use bin with ich.",
      tokens: [],
      feminineTokens: [],
      masculineTokens: [],
    })),
  };
  const r = await generateMessageOnce(
    viewers,
    { provider: "openai", apiKey: "fixture", model: "fixture" } as any,
    async () =>
      new Response(
        JSON.stringify({
          choices: [{ message: { content: JSON.stringify(content) } }],
        }),
      ),
  );
  const meta = r.v0.tokens.find((t: any) => t.blabAuthoredCorrection) as any;
  if (meta?.blabAuthoredCorrection?.correctionText !== viewers[0].text) {
    throw Error("unsafe missing provenance fallback");
  }
});
