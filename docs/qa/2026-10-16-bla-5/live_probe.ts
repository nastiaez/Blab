import {
  generateMessageOnce,
  type PreparedViewer,
} from "../../../supabase/functions/translate-message/single_call.ts";
import {
  DEFAULT_OPENROUTER_MODEL,
  WORD_HELP_POLICY,
} from "../../../supabase/functions/translate-message/rulebook.ts";
const env = await Deno.readTextFile(
  Deno.args[0] ?? "supabase/.env.local",
);
const values = Object.fromEntries(
  env.split("\n").filter((x) => x.includes("=") && !x.startsWith("#")).map(
    (x) => {
      const i = x.indexOf("=");
      return [x.slice(0, i), x.slice(i + 1).trim().replace(/^['"]|['"]$/g, "")];
    },
  ),
);
const credential = {
  provider: "openrouter" as const,
  apiKey: values.OPEN_ROUTER_KEY,
  model: Deno.env.get("BLAB_PROBE_MODEL") || DEFAULT_OPENROUTER_MODEL,
  useOpenRouterProviderPolicy: true,
};
const cases = [
  {
    id: "reported",
    text:
      "You don't have the full translation of the message. Also, I can't listen to the whole message or sentence.",
    pairs: [["en", "uk"], ["en", "de"]],
  },
  {
    id: "repeated-context",
    text: "I left the bank and sat on the river bank.",
    pairs: [["en", "uk"], ["en", "es"]],
  },
  {
    id: "german-function-words",
    text: "Ich warte auf den Bus.",
    pairs: [["de", "en"], ["de", "uk"]],
  },
];
for (const c of cases) {
  const viewers: PreparedViewer[] = c.pairs.map((
    [targetLang, interfaceLang],
    i,
  ) => ({
    key: `v${i}`,
    messageId: c.id,
    sourceHash: "probe",
    text: c.text,
    targetLang,
    interfaceLang,
    formContext: {
      viewerName: i ? "Bob" : "Alice",
      partnerName: i ? "Alice" : "Bob",
      messageAuthor: i ? "partner" : "viewer",
      tone: "informal",
    },
  }));
  const result = await generateMessageOnce(viewers, credential);
  await Deno.writeTextFile(
    new URL(`./${c.id}.json`, import.meta.url),
    JSON.stringify(
      {
        wordHelpPolicy: WORD_HELP_POLICY.version,
        source: c.text,
        viewers,
        result,
      },
      null,
      2,
    ),
  );
  console.log(
    c.id,
    JSON.stringify(
      Object.fromEntries(
        Object.entries(result).map(([k, v]) => [
          k,
          v.tokens.filter((t) => t.isContent).map((t) => [t.text, t.gloss]),
        ]),
      ),
    ),
  );
}
