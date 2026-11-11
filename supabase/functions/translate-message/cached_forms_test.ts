import { cachedFormAlternatives } from "./participant_forms.ts";
Deno.test("cached envelope-only result survives without grammatical choices", () => {
  const raw = { blabGenerationEnvelope: { version: 1 } };
  if (
    JSON.stringify(cachedFormAlternatives(raw, "de", "correction")) !==
      JSON.stringify(raw)
  ) throw Error("lost provenance");
});
Deno.test("malformed optional cached forms cannot crash a valid translation", () => {
  for (const raw of [{ before: 1, feminine: null }, {}, 2, null]) {
    if (cachedFormAlternatives(raw, "de", "translation") !== null) {
      throw Error("invalid form retained");
    }
  }
});
Deno.test("cached valid grammatical choice and envelope are preserved", () => {
  const raw = {
    before: "",
    feminine: "müde",
    masculine: "bereit",
    after: "",
    blabGenerationEnvelope: {},
  };
  if (cachedFormAlternatives(raw, "de", "translation") !== raw) {
    throw Error("valid choice lost");
  }
});
Deno.test("irrelevant grammatical choice retains independent envelope", () => {
  const raw = {
    before: "",
    feminine: "Hallo",
    masculine: "Hallo",
    after: "",
    blabGenerationEnvelope: {},
  };
  const actual = cachedFormAlternatives(raw, "de", "translation");
  if (
    JSON.stringify(actual) !== JSON.stringify({ blabGenerationEnvelope: {} })
  ) throw Error("envelope lost");
});
