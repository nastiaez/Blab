// Prepare only: no database writes. Compare-and-swap SQL retains sentence/history.
import {
  parseWordMetadataRepairResult,
  wordMetadataRepairSystemPrompt,
} from "../../../supabase/functions/translate-message/contract.ts";
import { fetchChatCompletion } from "../../../supabase/functions/translate-message/provider.ts";
import {
  DEFAULT_OPENROUTER_MODEL,
  WORD_HELP_POLICY,
} from "../../../supabase/functions/translate-message/rulebook.ts";
const [snapshotPath, envPath, outputPath] = Deno.args;
if (!snapshotPath || !envPath || !outputPath) {
  throw new Error(
    "Usage: prepare_repair.ts snapshot.json provider.env output.json",
  );
}
const snapshot = JSON.parse(await Deno.readTextFile(snapshotPath));
const rows = snapshot.rows;
if (!Array.isArray(rows) || rows.length !== 1) {
  throw new Error("Expected one exact cache variant");
}
const row = rows[0];
const env = Object.fromEntries(
  (await Deno.readTextFile(envPath)).split("\n").filter((x) =>
    x.includes("=") && !x.startsWith("#")
  ).map((x) => {
    const i = x.indexOf("=");
    return [x.slice(0, i), x.slice(i + 1).trim().replace(/^['"]|['"]$/g, "")];
  }),
);
const response = await fetchChatCompletion({
  provider: "openrouter",
  apiKey: env.OPEN_ROUTER_KEY,
  model: DEFAULT_OPENROUTER_MODEL,
  useOpenRouterProviderPolicy: true,
}, {
  messages: [{
    role: "system",
    content: wordMetadataRepairSystemPrompt(
      row.target_lang,
      row.interface_lang,
      row.interface_text,
    ),
  }, {
    role: "user",
    content: JSON.stringify({
      sentence: row.translation_text,
      knownLanguageSentence: row.interface_text,
    }),
  }],
  temperature: 0,
  max_tokens: 5000,
  response_format: { type: "json_object" },
});
if (!response.ok) throw new Error(`provider_http_${response.status}`);
const data = await response.json();
const parsed = parseWordMetadataRepairResult(
  data.choices[0].message.content,
  row.translation_text,
);
if (!parsed) throw new Error("Invalid metadata-only repair");
const tokens = parsed.map((t) => ({
  ...t,
  wordHelpVersion: WORD_HELP_POLICY.version,
}));
const output = {
  messageId: row.message_id,
  targetLang: row.target_lang,
  primaryKnownLanguage: row.interface_lang,
  sourceHash: row.source_hash,
  immutableSentence: row.translation_text,
  oldTokens: row.tokens,
  tokens,
};
await Deno.writeTextFile(outputPath, JSON.stringify(output, null, 2));
console.log(
  JSON.stringify(
    tokens.filter((t) => t.isContent).map((t) => [t.text, t.gloss]),
  ),
);
