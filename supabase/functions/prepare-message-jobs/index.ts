import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { workerBatchLimit } from "./contract.ts";
import { type LeasedJob, runMessageBatch } from "./single_call_worker.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("BLAB_SUPABASE_SERVICE_ROLE_KEY")?.trim() ||
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  if (
    request.headers.get("Authorization") !==
      `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`
  ) {
    return json({ error: "unauthorized" }, 401);
  }
  let input: unknown = {};
  try {
    input = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const limit = workerBatchLimit(input);
  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const processJobs = async () => {
    let claimed = 0;
    while (claimed < limit) {
      const { data, error } = await admin.rpc(
        "claim_message_preparation_jobs_for_worker",
        { p_limit: limit - claimed },
      );
      if (error) throw new Error("claim_failed");
      const jobs = (Array.isArray(data) ? data : []) as LeasedJob[];
      if (!jobs.length) break;
      claimed += jobs.length;
      const batches = new Map<string, LeasedJob[]>();
      for (const job of jobs) {
        const key = `${job.message_id}:${job.source_version}`;
        batches.set(key, [...(batches.get(key) ?? []), job]);
      }
      await Promise.all(
        [...batches.values()].map((batch) => runMessageBatch(admin, batch)),
      );
    }
    return json({ status: "processed", claimed });
  };
  EdgeRuntime.waitUntil(
    processJobs().catch(() => {
      console.error("blab_worker_failed", { reason: "worker_interrupted" });
    }),
  );
  return json({ status: "accepted" }, 202);
});
