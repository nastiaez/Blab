import { hasParticipantFormDifference } from "./participant_forms.ts";
import { parseProviderResult } from "./contract.ts";
import { restoreAcceptedReadable } from "./readable_delivery.ts";

const cases: [string, string, string, boolean][] = [
  ["de", "Schreib deiner Mutter", "Schreib deinem Mutter", false],
  ["de", "Mit dieser App", "Mit diesem App", false],
  ["de", "Ich sehe meine Mutter.", "Ich sehe meinen Mutter.", false],
  ["de", "Das ist euer Buch.", "Das ist eurem Buch.", false],
  ["de", "Ich bin Lehrerin.", "Ich bin Lehrer.", true],
  ["de", "Sie ist meine Freundin.", "Er ist mein Freund.", true],
  ["de", "Das ist ihr Buch.", "Das ist sein Buch.", true],
  ["de", "Ich bin deine.", "Ich bin deiner.", true],
  ["de", "Du bist müde.", "Du bist müde.", false],
  ["uk", "Ти ходила вчора?", "Ти ходив вчора?", true],
  ["es", "Estoy cansada.", "Estoy cansado.", true],
  ["fr", "Je suis prête.", "Je suis prêt.", true],
];
for (const [language, feminine, masculine, expected] of cases) {
  Deno.test(`${language}: ${feminine} / ${masculine}`, () => {
    if (
      hasParticipantFormDifference(language, feminine, masculine) !== expected
    ) {
      throw new Error("Unexpected participant-form relevance");
    }
  });
}

Deno.test("old German noun-case metadata cannot survive provider/cache parsing", () => {
  const saved = {
    mode: "translation",
    sourceLang: "en",
    translation: "Schreib deiner Mutter",
    interfaceText: "Write to your mother",
    explanation: null,
    confidence: null,
    formAlternatives: {
      before: "Schreib ",
      feminine: "deiner",
      masculine: "deinem",
      after: " Mutter",
      subjectName: "Alice",
      subjectIsViewer: true,
      subjectRole: "recipient",
      suggestedForm: "feminine",
    },
  };
  const provider = parseProviderResult(
    JSON.stringify(saved),
    "Write to your mother",
    "de",
    "en",
    undefined,
    true,
  );
  const restored = restoreAcceptedReadable(
    saved,
    "Write to your mother",
    "de",
    "en",
  );
  for (const result of [provider, restored]) {
    if (
      !result || result.translation !== saved.translation ||
      result.formAlternatives !== null
    ) {
      throw new Error(
        "Preserve the readable German but reject false participant forms",
      );
    }
  }
});
