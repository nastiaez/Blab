import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  jobFailureReason,
  orderedJobs,
  planJobOutcome,
  type PreparationJob,
  settleJobs,
  workerBatchLimit,
} from "./contract.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("BLAB_SUPABASE_SERVICE_ROLE_KEY")?.trim() ||
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

type ClaimedJob = PreparationJob & {
  message_id: string;
  lease_token: string;
  viewer_id: string;
};

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
    const allOutcomes: Array<{
      jobId: string;
      status: number;
      outcome: string;
    }> = [];
    while (allOutcomes.length < limit) {
      const { data, error } = await admin.rpc(
        "claim_message_preparation_jobs_for_worker",
        { p_limit: limit - allOutcomes.length },
      );
      if (error) return json({ error: "claim_failed" }, 500);
      const jobs = orderedJobs(
        (Array.isArray(data) ? data : []) as ClaimedJob[],
      );
      if (jobs.length === 0) break;
      const outcomes = await settleJobs(jobs, async (job) => {
        let status = 503;
        let retryAfterSeconds = 0;
        let reason = "translation_unreachable";
        try {
          const response = await fetch(
            `${SUPABASE_URL}/functions/v1/translate-message`,
            {
              method: "POST",
              signal: AbortSignal.timeout(25000),
              headers: {
                "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
                "Content-Type": "application/json",
              },
              body: JSON.stringify({
                jobId: job.id,
                jobLease: job.lease_token,
              }),
            },
          );
          status = response.status;
          const retryAfter = response.headers.get("Retry-After");
          if (retryAfter) {
            const numeric = Number(retryAfter);
            retryAfterSeconds = Number.isFinite(numeric)
              ? Math.max(0, numeric)
              : Math.max(0, (Date.parse(retryAfter) - Date.now()) / 1000) || 0;
          }
          try {
            const body = await response.json() as {
              error?: unknown;
              reason?: unknown;
            };
            reason = jobFailureReason(body, response.status);
          } catch {
            reason = response.ok ? "ready" : `http_${response.status}`;
          }
        } catch {
          status = 503;
        }
        const outcome = planJobOutcome({
          status,
          attempts: job.attempts,
          retryAfterSeconds,
          jitter: Math.random(),
        });
        if (outcome.kind !== "ready") {
          await admin.rpc("leased_translation_action", {
            p_job_id: job.id,
            p_lease_token: job.lease_token,
            p_action: "finish",
            p_payload: {
              outcome: outcome.kind,
              reason,
              delaySeconds: outcome.kind === "retry" ? outcome.delaySeconds : 0,
            },
          });
        }
        return { status, outcome: outcome.kind };
      });
      allOutcomes.push(...outcomes.map((outcome) => ({
        jobId: outcome.job.id,
        status: outcome.result?.status ?? 503,
        outcome: outcome.result?.outcome ?? "retry",
      })));
    }
    return json({
      status: "processed",
      claimed: allOutcomes.length,
      outcomes: allOutcomes,
    });
  };
  EdgeRuntime.waitUntil(
    processJobs().catch(() => {
      console.error("blab_worker_failed", { reason: "worker_interrupted" });
    }),
  );
  return json({ status: "accepted" }, 202);
});
