// Local-only live acceptance: exercises the production worker with real leases.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { runMessageBatch } from "../supabase/functions/prepare-message-jobs/single_call_worker.ts";

const input = JSON.parse(await Deno.readTextFile(Deno.args[0]));
const url = Deno.env.get("QA_SUPABASE_URL")!;
if (url !== "http://127.0.0.1:57321") throw Error("Local QA only");
const admin = createClient(url, Deno.env.get("QA_SERVICE_ROLE")!, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const originalFetch = globalThis.fetch;
const metrics: unknown[] = [];
globalThis.fetch = async (request, init) => {
  const response = await originalFetch(request, init);
  if (
    String(request).startsWith("https://openrouter.ai/api/v1/chat/completions")
  ) {
    const body = await response.clone().json();
    metrics.push({
      status: response.status,
      model: body.model,
      usage: body.usage,
    });
  }
  return response;
};
await runMessageBatch(admin, input);
await Deno.writeTextFile(Deno.args[1], JSON.stringify({ metrics }, null, 2));
