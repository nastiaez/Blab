// Synthetic messages only; live provider uses production-equivalent privacy routing.
import {
  generateMessageOnce,
  type PreparedViewer,
} from "../supabase/functions/translate-message/single_call.ts";
import { singleCallRequest } from "../supabase/functions/translate-message/single_call.ts";
import { providerCredentials } from "../supabase/functions/translate-message/contract.ts";
const env = await Deno.readTextFile(
  Deno.env.get("BLAB_EVAL_ENV_FILE") ?? "env/translation-evaluation.env",
);
const get = (name: string) =>
  env.split("\n").find((x) => x.startsWith(name + "="))?.split("=").slice(1)
    .join("=").trim().replace(/^['"]|['"]$/g, "");
const credential = providerCredentials({
  openRouterKey: get("OPEN_ROUTER_KEY"),
  openRouterModel: get("OPENROUTER_MODEL"),
  environment: "production",
})[0];
const cases = [
  {
    text: "Review draftIk heb twee boeken.",
    targets: ["nl", "es"],
    known: ["en", "uk"],
  },
  { text: "Ik ben moe.", targets: ["nl", "es"], known: ["en", "uk"] },
  {
    text: "Estoy cansado.",
    targets: ["nl", "es"],
    known: ["en", "uk"],
    reverse: true,
  },
  {
    text: "Ich habe ein Buch gelest.",
    targets: ["de", "de"],
    known: ["en", "en"],
  },
  {
    text: "What did you do yesterday?",
    targets: ["uk", "uk"],
    known: ["en", "en"],
  },
  { text: "Write to your mother", targets: ["de", "uk"], known: ["en", "es"] },
  { text: "With this app", targets: ["de", "uk"], known: ["en", "es"] },
  { text: "I am a teacher.", targets: ["de", "es"], known: ["en", "uk"] },
  {
    text: "Not seven",
    targets: ["de", "hi"],
    known: ["en", "uk"],
    context: "Let us meet at six.",
  },
  {
    text: "Hii Nastia when are you coming back",
    targets: ["de", "uk"],
    known: ["en", "es"],
  },
  { text: "okay", targets: ["de", "uk"], known: ["en", "es"] },
  {
    text: "I will bring 2 books tomorrow, not today 😊",
    targets: ["ta", "fr"],
    known: ["en", "es"],
  },
  {
    text: "Please visit https://example.com @alice #books",
    targets: ["it", "pt"],
    known: ["en", "tr"],
  },
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
    messageId: "synthetic",
    sourceHash: "synthetic",
    text: c.text,
    targetLang,
    interfaceLang: c.known[i],
    formContext: {
      viewerName: i === 0 ? "Alice Local" : "Bob Local",
      partnerName: i === 0 ? "Bob Local" : "Alice Local",
      messageAuthor: (i === 0) !== !!c.reverse ? "viewer" : "partner",
      tone: "informal",
    },
    context: c.context
      ? [{
        speaker: i === 0 ? "partner" : "viewer",
        text: c.context,
        isReply: true,
      }]
      : [],
  }));
  const request = singleCallRequest(viewers);
  const start = performance.now();
  let calls = 0, usage: unknown = null, raw: unknown = null;
  try {
    const results = await generateMessageOnce(
      viewers,
      credential,
      async (u, o) => {
        calls++;
        const r = await fetch(u, o);
        const body = await r.clone().json();
        usage = body.usage;
        raw = body.choices?.[0]?.message?.content;
        return r;
      },
    );
    rows.push({
      text: c.text,
      calls,
      ms: Math.round(performance.now() - start),
      usage,
      results,
      requestBytes: JSON.stringify(request).length,
    });
    console.log(
      JSON.stringify({
        text: c.text,
        calls,
        ms: Math.round(performance.now() - start),
        usage,
      }),
    );
  } catch (e) {
    rows.push({ text: c.text, calls, error: String(e), raw, usage });
    console.log(JSON.stringify({ text: c.text, error: String(e) }));
  }
}
await Deno.writeTextFile(
  "/tmp/blab-compact-live.json",
  JSON.stringify(rows, null, 2),
);
if (rows.some((r) => "error" in r)) Deno.exit(1);
