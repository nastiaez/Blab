import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import {
  FORM_RELEVANT_TARGET_LANGS,
  LANG_NAMES,
  LATIN_TARGETS,
} from "./rulebook.ts";
import { unsupportedSourceScript } from "./contract.ts";

Deno.test("new language scripts are supported without admitting unrelated scripts", () => {
  for (const word of ["안녕하세요", "नमस्कार", "cześć", "hyvää", "rødgrød"]) {
    assertEquals(unsupportedSourceScript(word), false, word);
  }
  assertEquals(unsupportedSourceScript("مرحبا"), true);
});
Deno.test("language registry and participant agreement cover BLA-13", () => {
  for (const code of ["ko", "fi", "pl", "da", "mr"]) assert(code in LANG_NAMES);
  for (const code of ["fi", "pl", "da"]) assert(LATIN_TARGETS.has(code));
  for (const code of ["mr", "pl"]) assert(FORM_RELEVANT_TARGET_LANGS.has(code));
  for (const code of ["ko", "fi", "da"]) {
    assert(!FORM_RELEVANT_TARGET_LANGS.has(code));
  }
});

Deno.test("Polish live grammatical alternatives survive explanatory word glosses", async () => {
  const { generateMessageOnce } = await import("./single_call.ts");
  const payload = JSON.parse(
    await Deno.readTextFile(
      new URL(
        "../../../docs/qa/16713/polish-provider-raw.json",
        import.meta.url,
      ),
    ),
  );
  const result = await generateMessageOnce([{
    key: "review",
    messageId: "fixture",
    sourceHash: "fixture",
    text: "I was tired yesterday.",
    targetLang: "pl",
    interfaceLang: "en",
    formContext: {
      viewerName: "Alice",
      partnerName: "Bob",
      messageAuthor: "viewer",
      tone: "informal",
    },
  }], {
    provider: "openrouter",
    apiKey: "fixture",
    model: "fixture",
    useOpenRouterProviderPolicy: false,
  }, async () => new Response(JSON.stringify(payload), { status: 200 }));
  assert(result.review.formAlternatives);
  assertEquals(result.review.formAlternatives.subjectIsViewer, true);
  const f = result.review.formAlternatives;
  assertEquals(f.before + f.masculine + f.after, "Byłem wczoraj zmęczony.");
  assertEquals(f.before + f.feminine + f.after, "Byłam wczoraj zmęczona.");
});
