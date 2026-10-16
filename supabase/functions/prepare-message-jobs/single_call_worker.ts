import { commitViewers } from "./commit_viewers.ts";
import {
  generateMessageOnce,
  type PreparedViewer,
} from "../translate-message/single_call.ts";
import { providerCredentials } from "../translate-message/contract.ts";
import { SINGLE_CALL_POLICY } from "../translate-message/rulebook.ts";
import { planJobOutcome } from "./contract.ts";
export type LeasedJob = {
  id: string;
  message_id: string;
  source_version: string;
  lease_token: string;
  attempts: number;
};
type Admin = {
  rpc: (
    name: string,
    args: Record<string, unknown>,
  ) => PromiseLike<{ data: unknown; error: unknown }>;
};

export async function runMessageBatch(admin: Admin, jobs: LeasedJob[]) {
  const pending: Array<{ job: LeasedJob; viewer: PreparedViewer }> = [];
  const backoff = { untilMs: 0 };
  try {
    for (const job of jobs) {
      const reply = await admin.rpc("leased_translation_action", {
        p_job_id: job.id,
        p_lease_token: job.lease_token,
        p_action: "prepare",
      });
      if (reply.error) throw new Error("prepare_failed");
      const p = reply.data as Record<string, unknown>;
      if (p?.status === "cached" || p?.status === "no_aid_needed") continue;
      if (p?.status !== "ready") {
        await admin.rpc("leased_translation_action", {
          p_job_id: job.id,
          p_lease_token: job.lease_token,
          p_action: "finish",
          p_payload: { outcome: "stale", reason: "preparation_stale" },
        });
        continue;
      }
      if (
        [p.messageId, p.text, p.sourceHash, p.targetLang, p.interfaceLang].some(
          (v) => typeof v !== "string",
        )
      ) throw new Error("invalid_preparation");
      pending.push({
        job,
        viewer: {
          key: `v${pending.length}`,
          messageId: p.messageId as string,
          text: p.text as string,
          sourceHash: p.sourceHash as string,
          targetLang: p.targetLang as string,
          interfaceLang: p.interfaceLang as string,
          context: p.context,
          formContext: p.formContext,
        },
      });
    }
    if (!pending.length) return;
    const credential = providerCredentials({
      openRouterKey: Deno.env.get("OPEN_ROUTER_KEY"),
      openAiKey: Deno.env.get("OPENAI_API_KEY"),
      openRouterModel: Deno.env.get("OPENROUTER_MODEL"),
      openAiModel: Deno.env.get("OPENAI_MODEL"),
      environment: Deno.env.get("BLAB_ENV"),
      openRouterProviderPolicy: Deno.env.get("OPENROUTER_PROVIDER_POLICY"),
    })[0];
    if (!credential) throw new Error("missing_provider_key");
    credential.backoff = backoff;
    const results = await generateMessageOnce(
      pending.map((p) => p.viewer),
      credential,
      undefined,
      true,
    );
    const completions = await commitViewers(
      admin.rpc.bind(admin),
      pending.map(({ job, viewer }) => ({
        jobId: job.id,
        lease: job.lease_token,
        result: results[viewer.key]
          ? {
            ...results[viewer.key],
            contractVersion: SINGLE_CALL_POLICY.contractVersion,
          }
          : null,
      })),
    );
    for (const completion of completions) {
      if (!completion.error) continue;
      const job = pending.find((p) => p.job.id === completion.jobId)!.job;
      const outcome = planJobOutcome({
        status: 503,
        retryAfterSeconds: 0,
        attempts: job.attempts,
      });
      await admin.rpc("leased_translation_action", {
        p_job_id: job.id,
        p_lease_token: job.lease_token,
        p_action: "finish",
        p_payload: {
          outcome: outcome.kind,
          reason: completion.error,
          delaySeconds: outcome.kind === "retry" ? outcome.delaySeconds : 0,
        },
      });
    }
    console.log("translation_message_batch_settled", {
      messageId: jobs[0].message_id,
      viewers: pending.length,
      ready: completions.filter((c) => !c.error).length,
      failed: completions.filter((c) => c.error).length,
    });
  } catch (e) {
    const reason = e instanceof Error && /^[a-zA-Z0-9_]+$/.test(e.message)
      ? e.message
      : "batch_failed";
    // Only the durable worker schedules bounded retries, never a second request
    // while a successful attempt is in flight. Fencing protects late workers.
    for (const job of jobs) {
      const outcome = planJobOutcome({
        status: /^provider_http_\d{3}$/.test(reason)
          ? Number(reason.slice(-3))
          : 503,
        retryAfterSeconds: Math.max(0, (backoff.untilMs - Date.now()) / 1000),
        attempts: job.attempts,
      });
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
    console.error("translation_message_batch_failed", {
      messageId: jobs[0].message_id,
      reason,
    });
  }
}
