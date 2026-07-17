import {
  characterCount,
  MAX_CHARS,
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

Deno.test("accepts 2000 characters and rejects 2001", () => {
  const accepted = validateRequest({
    text: "a".repeat(MAX_CHARS),
    sourceLang: "auto",
    targetLang: "de",
  });
  assert("request" in accepted, "maximum-length request should pass");

  const rejected = validateRequest({
    text: "a".repeat(MAX_CHARS + 1),
    sourceLang: "auto",
    targetLang: "de",
  });
  assert(
    "error" in rejected && rejected.error === "text_too_long",
    "over-limit request should fail",
  );
});

Deno.test("auto-source prompt requests normalized bilingual output", () => {
  const prompt = systemPrompt("auto", "uk");
  assert(prompt.includes("Detect the input language"), "source detection");
  assert(prompt.includes('"translation"'), "target-language output");
  assert(prompt.includes('"english"'), "English output");
  assert(prompt.includes('"sourceLang"'), "detected source output");
});
