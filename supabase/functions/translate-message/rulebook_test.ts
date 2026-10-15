import {
  acknowledgementPromptRule,
  isStandaloneAcknowledgement,
  renderTranslationRulebook,
} from "./rulebook.ts";
import {
  focusedTranslationRetryMessages,
  semanticTranslationAuditSystemPrompt,
  systemPrompt,
} from "./contract.ts";

Deno.test("generated translation rulebook is current", async () => {
  const actual = await Deno.readTextFile(
    new URL("../../../docs/translation-rulebook.md", import.meta.url),
  );
  if (actual !== renderTranslationRulebook()) {
    throw new Error("Regenerate translation rulebook");
  }
});
Deno.test("acknowledgement policy is shared by retry and audit prompts", () => {
  const retry = focusedTranslationRetryMessages({
    sourceLang: "en",
    targetLang: "de",
    interfaceLang: "en",
    text: "okay",
  });
  for (
    const prompt of [
      retry?.[0].content,
      systemPrompt("en", "de", "en"),
      semanticTranslationAuditSystemPrompt("en", "de", "en"),
    ]
  ) {
    if (!prompt?.includes(acknowledgementPromptRule())) {
      throw new Error("Missing canonical acknowledgement policy");
    }
  }
  for (const input of ["OK", " okay?! ", "ok…"]) {
    if (!isStandaloneAcknowledgement(input)) {
      throw new Error(`Rejected ${input}`);
    }
  }
  for (
    const input of [
      "okay tomorrow",
      "ok👍",
      "hotel",
      "!ok",
      "",
      "okay,",
      "Is it okay?",
    ]
  ) {
    if (isStandaloneAcknowledgement(input)) {
      throw new Error(`Exempted ${input}`);
    }
  }
});
