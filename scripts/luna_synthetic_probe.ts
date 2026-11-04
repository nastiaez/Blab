import { generateMessageOnce } from "../supabase/functions/translate-message/single_call.ts";
import { providerCredentials } from "../supabase/functions/translate-message/contract.ts";
import { runMessageBatch } from "../supabase/functions/prepare-message-jobs/single_call_worker.ts";
const file = await Deno.readTextFile(
  Deno.args[0] ?? (() => {
    throw Error("app_env_file_required");
  })(),
);
const key = file.split("\n").find((l) => l.startsWith("OPENAI_API_KEY="))!
  .split("=").slice(
    1,
  ).join("=").trim().replace(/^["']|["']$/g, "");
Deno.env.set("OPENAI_API_KEY", key);
Deno.env.set("OPENAI_MODEL", "gpt-6-luna");
Deno.env.set("BLAB_TRANSLATION_PROVIDER", "openai");
const credential =
  providerCredentials({ provider: "openai", openAiKey: key })[0];
const viewer = {
  key: "v0",
  messageId: crypto.randomUUID(),
  sourceHash: "synthetic-luna-only",
  text: "I will bring tea tomorrow, not today.",
  targetLang: "de",
  interfaceLang: "en",
  context: [],
};
const output = await generateMessageOnce([viewer], credential);
if (!output.v0?.translation) throw Error("synthetic_translation_missing");
console.log(
  JSON.stringify({
    boundary: "actual_compact_generation",
    model: credential.model,
    result: output,
  }),
);
let completed = 0;
const calls: string[] = [];
await runMessageBatch({
  rpc: async (name, args) => {
    calls.push(name);
    if (name === "prepare_translation_viewers") {
      return {
        data: [{
          id: "synthetic-job",
          prepared: { status: "ready", ...viewer },
        }],
        error: null,
      };
    }
    if (name === "complete_translation_message_batch") {
      const rows = args.p_results as Array<{ result: { translation: string } }>;
      if (!rows[0]?.result?.translation) throw Error("empty_worker_output");
      completed++;
      return { data: true, error: null };
    }
    throw Error("unexpected_rpc_" + name);
  },
}, [{
  id: "synthetic-job",
  message_id: viewer.messageId,
  source_version: viewer.sourceHash,
  lease_token: "synthetic-lease",
  attempts: 1,
}]);
if (completed !== 1) throw Error("worker_completion_missing");
console.log(
  JSON.stringify({
    boundary: "real_worker_real_provider_synthetic_rpc_no_database",
    completed,
    calls,
    model: credential.model,
  }),
);
