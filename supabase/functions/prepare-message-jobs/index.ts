import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  orderedJobs,
  planJobOutcome,
  type PreparationJob,
  settleJobs,
  workerBatchLimit,
} from "./contract.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

type ClaimedJob = PreparationJob & {
  message_id: string;
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
      let reason = "translation_unreachable";
      try {
        const response = await fetch(
          `${SUPABASE_URL}/functions/v1/translate-message`,
          {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({ jobId: job.id }),
          },
        );
        status = response.status;
        try {
          const body = await response.json() as {
            error?: unknown;
            reason?: unknown;
          };
          if (typeof body.error === "string") reason = body.error;
          else if (typeof body.reason === "string") reason = body.reason;
          else reason = response.ok ? "ready" : `http_${response.status}`;
        } catch {
          reason = response.ok ? "ready" : `http_${response.status}`;
        }
      } catch {
        status = 503;
      }
      const outcome = planJobOutcome({ status, attempts: job.attempts });
      if (outcome.kind !== "ready") {
        await admin.rpc("finish_message_preparation_job", {
          p_job_id: job.id,
          p_outcome: outcome.kind,
          p_error: reason,
          p_delay_seconds: outcome.kind === "retry" ? outcome.delaySeconds : 0,
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
});
