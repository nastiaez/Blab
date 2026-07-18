import {
  characterCount,
  MAX_CHARS,
  OPENROUTER_PROVIDER,
  parseProviderResult,
  systemPrompt,
  validateRequest,
} from "./contract.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

Deno.test("counts user-perceived characters", () => {
  assert(characterCount("a") === 1, "ASCII character count");
  assert(characterCount("👨‍👩‍👧‍👦") === 1, "joined emoji character count");
});

Deno.test("accepts only a message UUID", () => {
  const accepted = validateRequest({
    messageId: "10000000-0000-4000-8000-000000000001",
  });
  assert("request" in accepted, "message UUID should pass");

  const rejected = validateRequest({
    messageId: "not-a-message-id",
  });
  assert(
    "error" in rejected && rejected.error === "invalid_message_id",
    "invalid ID should fail",
  );
});

Deno.test("provider route is pinned to Azure ZDR endpoints", () => {
  assert(OPENROUTER_PROVIDER.only.join(",") === "azure", "Azure only");
  assert(OPENROUTER_PROVIDER.zdr, "ZDR required");
  assert(OPENROUTER_PROVIDER.data_collection === "deny", "collection denied");
  assert(OPENROUTER_PROVIDER.require_parameters, "parameters required");
});

Deno.test("provider result must reproduce the translated text", () => {
  const valid = parseProviderResult(
    JSON.stringify({
      sourceLang: "en",
      translation: "Hallo!",
      english: "ignored",
      tokens: [
        { text: "Hallo", english: "Hello", isContent: true },
        { text: "!", isContent: false },
      ],
    }),
    "Hello!",
    "de",
  );
  assert(valid?.english === "Hello!", "English source is authoritative");

  const invalid = parseProviderResult(
    JSON.stringify({
      sourceLang: "en",
      translation: "Hallo!",
      english: "Hello!",
      tokens: [{ text: "Falsch", isContent: true }],
    }),
    "Hello!",
    "de",
  );
  assert(invalid === null, "token mismatch should fail");
});

Deno.test("auto-source prompt requests normalized bilingual output", () => {
  const prompt = systemPrompt("auto", "uk");
  assert(prompt.includes("Detect the input language"), "source detection");
  assert(prompt.includes('"translation"'), "target-language output");
  assert(prompt.includes('"english"'), "English output");
  assert(prompt.includes('"sourceLang"'), "detected source output");
});

Deno.test("maximum character contract remains 2000", () => {
  assert(characterCount("a".repeat(MAX_CHARS)) === MAX_CHARS, "maximum length");
});
