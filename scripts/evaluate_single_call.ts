import {
  generateMessageOnce,
  type PreparedViewer,
} from "../supabase/functions/translate-message/single_call.ts";
import { providerCredentials } from "../supabase/functions/translate-message/contract.ts";
const credential = providerCredentials({
  openRouterKey: Deno.env.get("OPEN_ROUTER_KEY"),
  environment: "local",
  openRouterProviderPolicy: "false",
})[0];
const cases = [
  { text: "Okay", targets: ["de", "uk"] },
  { text: "Hii nastia when are you coming back", targets: ["de", "uk"] },
  { text: "Wenn ich du Message senden", targets: ["de", "es"] },
  { text: "Los geht’s", targets: ["de", "uk"] },
  {
    text: "Not seven",
    targets: ["de", "uk"],
    context: [{ speaker: "partner", text: "Let's meet at six." }],
  },
  { text: "What did you do yesterday?", targets: ["uk", "fr"] },
  { text: "I will bring the gift tomorrow, not today.", targets: ["de", "hi"] },
  { text: "Sounds good", targets: ["de", "de"] },
  { text: "Did you go home yesterday?", targets: ["uk", "uk"] },
];
const rows = [];
for (
  const c of cases.filter((c) =>
    !Deno.env.get("CASE_FILTER") ||
    c.text.includes(Deno.env.get("CASE_FILTER")!)
  )
) {
  const viewers = c.targets.map((targetLang, i): PreparedViewer => ({
    key: `v${i}`,
    messageId: crypto.randomUUID(),
    sourceHash: "evaluation",
    text: c.text,
    targetLang,
    interfaceLang: i === 0 ? "en" : "uk",
    context: c.context ?? [],
    formContext: {
      viewerName: i === 0 ? "Alice" : "Bob",
      partnerName: i === 0 ? "Bob" : "Alice",
      messageAuthor: i === 0 ? "viewer" : "partner",
      tone: "informal",
    },
  }));
  viewers[1].messageId = viewers[0].messageId;
  const start = performance.now();
  try {
    const results = await generateMessageOnce(
      viewers,
      credential,
      async (url, init) => {
        const response = await fetch(url, init);
        await Deno.writeTextFile(
          "/tmp/blab-single-call-raw.json",
          JSON.stringify(await response.clone().json(), null, 2),
        );
        return response;
      },
    );
    const row = {
      text: c.text,
      ms: Math.round(performance.now() - start),
      results,
    };
    rows.push(row);
    console.log(JSON.stringify(row));
  } catch (e) {
    const row = {
      text: c.text,
      ms: Math.round(performance.now() - start),
      error: String(e),
    };
    rows.push(row);
    console.log(JSON.stringify(row));
  }
}
await Deno.writeTextFile(
  "/tmp/blab-single-call-live.json",
  JSON.stringify(rows, null, 2),
);
