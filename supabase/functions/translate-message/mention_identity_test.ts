import { assertEquals, assertThrows } from "jsr:@std/assert";
import {
  protectMentions,
  restoreMentionResult,
  restoreMentionText,
} from "./mention_identity.ts";
const a = "11111111-1111-4111-8111-111111111111",
  b = "22222222-2222-4222-8222-222222222222";
Deno.test("duplicate names preserve identity through translated reordering", () => {
  const p = protectMentions("@Alex and @Alex", [{
    userId: a,
    label: "Alex",
    start: 0,
  }, { userId: b, label: "Alex", start: 10 }]);
  const r = restoreMentionText(`${p.handles[1]} und ${p.handles[0]}`, p);
  assertEquals(r.text, "@Alex und @Alex");
  assertEquals(r.mentions.map((m) => m.userId), [b, a]);
  assertEquals(r.mentions.map((m) => m.start), [0, 10]);
});
Deno.test("missing or duplicated identities fail closed before delivery", () => {
  const p = protectMentions("@Alex", [{ userId: a, label: "Alex", start: 0 }]);
  assertThrows(() => restoreMentionText("Alex", p));
  assertThrows(() => restoreMentionText(`${p.handles[0]} ${p.handles[0]}`, p));
});
Deno.test("restored output uses plain text for old clients and trusted sidecar", () => {
  const p = protectMentions("👋 @Alex", [{
    userId: a,
    label: "Alex",
    start: 3,
  }]);
  const r = restoreMentionResult({
    translation: `Hi ${p.handles[0]}`,
    interfaceText: `Hallo ${p.handles[0]}`,
    tokens: [],
  }, p);
  assertEquals(r.translation, "Hi @Alex");
  assertEquals(r.tokens.length, 1);
  assertEquals(JSON.stringify(r).includes("@blab_"), false);
});

Deno.test("invented internal and ordinary handles fail with no selected mentions", () => {
  for (
    const [source, translated] of [["Working ash", "Ich arbeite, @blab_."], [
      "Was machst du",
      "What are you doing @Aswin_Ranganathan?",
    ], ["Hello", "Привіт @Олена"]]
  ) {
    assertThrows(() =>
      restoreMentionResult(
        { translation: translated, interfaceText: source },
        protectMentions(source, []),
      )
    );
  }
});
Deno.test("authored handles, emails, names and reordering remain ordinary text", () => {
  const source = "Ash @aswinckr mail A.Test+tag@example.com @blab_literal";
  const translated = "@blab_literal Ash mail A.Test+tag@example.com @aswinckr";
  assertEquals(
    restoreMentionText(translated, protectMentions(source, [])).text,
    translated,
  );
  assertEquals(restoreMentionText("Еш", protectMentions("Ash", [])).text, "Еш");
  for (const bad of ["Ash", "@aswinckr @aswinckr", "@aswinckr_extra"]) {
    assertThrows(() =>
      restoreMentionText(bad, protectMentions("@aswinckr", []))
    );
  }
});
Deno.test("selected identity permits Tamil suffix but not invented ASCII identity", () => {
  const p = protectMentions("@Alex", [{ userId: a, label: "Alex", start: 0 }]);
  assertEquals(restoreMentionText(`${p.handles[0]}-இடம்`, p).text, "@Alex-இடம்");
  assertThrows(() => restoreMentionText(`${p.handles[0]}_fake`, p));
  assertThrows(() => restoreMentionText(`${p.handles[0]} @invented`, p));
});
Deno.test("invalid optional mentions do not discard accepted sentences", () => {
  const r = restoreMentionResult({
    translation: "Hallo Ash",
    interfaceText: "Hello Ash",
    explanation: "@invented",
    tokens: [{ text: "Hallo Ash", gloss: "@invented" }],
    formAlternatives: {
      before: "",
      feminine: "@invented",
      masculine: "@invented",
      after: "",
    },
  }, protectMentions("Hello Ash", []));
  assertEquals(r.translation, "Hallo Ash");
  assertEquals(r.tokens, []);
  assertEquals(r.explanation, null);
  assertEquals(r.formAlternatives, null);
});
