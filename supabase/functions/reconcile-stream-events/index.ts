import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { StreamServer } from "../_shared/stream_server.ts";
import { advanceStreamErasure } from "../_shared/stream_account_erasure.ts";
import { eraseUploadedAsset } from "../_shared/stream_media_orphans.ts";
import { isMissingPrivateObject } from "../_shared/private_media_cleanup.ts";

const json = (body: unknown, status = 200) =>
  Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  const authority = Deno.env.get("BLAB_SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (
    !authority || request.headers.get("Authorization") !== `Bearer ${authority}`
  ) return json({ error: "unauthorized" }, 401);
  const key = Deno.env.get("STREAM_API_KEY"),
    secret = Deno.env.get("STREAM_API_SECRET");
  if (!key || !secret) return json({ error: "stream_not_configured" }, 503);
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, authority, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await admin.rpc("claim_stream_message_events", {
    p_limit: 8,
  });
  if (error) return json({ error: "event_claim_unavailable" }, 503);
  const server = new StreamServer(key, secret);
  const outcomes = await Promise.all(
    (data ?? []).map(
      async (
        event: {
          event_id: string;
          chat_id: string;
          message_id: string;
          lease_token: string;
          occurred_at: string;
        },
      ) => {
        let success = false;
        let reason = "reconciliation_failed";
        try {
          const current = await server.request(
            `messages/${event.message_id}`,
            undefined,
            { query: { show_deleted_message: "true" } },
          );
          const { error: applyError } = await admin.rpc(
            "apply_stream_message_snapshot",
            { p_chat_id: event.chat_id, p_snapshot: current.message },
          );
          if (!applyError) {
            const activity = await admin.rpc("apply_stream_message_activity", {
              p_chat_id: event.chat_id,
              p_snapshot: current.message,
              p_occurred_at: event.occurred_at,
            });
            if (!activity.error) success = true;
          }
        } catch {
          // Do not retain vendor payload/error bodies containing authored content.
          reason = "canonical_message_unavailable";
        }
        const { data: finished, error: finishError } = await admin.rpc(
          "finish_stream_message_event",
          {
            p_event_id: event.event_id,
            p_lease_token: event.lease_token,
            p_success: success,
            p_error: reason,
          },
        );
        return {
          state: finishError || finished !== true
            ? "lease_unsettled"
            : success
            ? "done"
            : "retry",
        };
      },
    ),
  );
  const cleanup = await admin.rpc("claim_stream_account_erasure", {
    p_limit: 4,
  });
  if (cleanup.error) return json({ error: "erasure_claim_unavailable" }, 503);
  const erased = await Promise.all((cleanup.data ?? []).map(async (job: {
    user_id: string;
    lease_token: string;
    task_id: string | null;
  }) => {
    let taskId = job.task_id, done = false, reason = "erasure_pending";
    try {
      const next = await advanceStreamErasure(server, job.user_id, taskId);
      taskId = next.taskId;
      done = next.done;
    } catch {
      reason = "erasure_unavailable";
    }
    const finished = await admin.rpc("finish_stream_account_erasure", {
      p_user_id: job.user_id,
      p_lease_token: job.lease_token,
      p_task_id: taskId,
      p_done: done,
      p_error: done ? null : reason,
    });
    return {
      state: finished.error || finished.data !== true
        ? "lease_unsettled"
        : done
        ? "done"
        : "retry",
    };
  }));
  const privateClaim = await admin.rpc("claim_stream_private_media_cleanup");
  if (privateClaim.error) {
    return json({ error: "private_media_claim_unavailable" }, 503);
  }
  const privateMediaOutcomes = await Promise.all(
    (privateClaim.data ?? []).map(
      async (
        asset: { bucket_id: string; object_path: string; lease_token: string },
      ) => {
        const removed = await admin.storage.from(asset.bucket_id).remove(
          [asset.object_path],
        );
        let success = !removed.error;
        if (success) {
          const probe = await admin.storage.from(asset.bucket_id)
            .download(asset.object_path);
          const missing = probe.error as {
            statusCode?: string;
            message?: string;
          } | null;
          success = isMissingPrivateObject(missing);
        }
        const finished = await admin.rpc(
          "finish_stream_private_media_cleanup",
          {
            p_path: asset.object_path,
            p_lease_token: asset.lease_token,
            p_success: success,
          },
        );
        return {
          state: finished.error || finished.data !== true
            ? "lease_unsettled"
            : success
            ? "done"
            : "retry",
        };
      },
    ),
  );
  const orphanClaim = await admin.rpc("claim_stream_media_orphans", {
    p_limit: 4,
  });
  if (orphanClaim.error) {
    return json({ error: "orphan_claim_unavailable" }, 503);
  }
  const orphanOutcomes = await Promise.all(
    (orphanClaim.data ?? []).map(async (asset: {
      asset_hash: string;
      lease_token: string;
      kind: "file" | "image";
      asset_url: string;
    }) => {
      let success = false;
      try {
        await eraseUploadedAsset(server, {
          kind: asset.kind,
          url: asset.asset_url,
        });
        success = true;
      } catch { /* Durable retry owns recovery. */ }
      const finished = await admin.rpc("finish_stream_media_orphan", {
        p_asset_hash: asset.asset_hash,
        p_lease_token: asset.lease_token,
        p_success: success,
      });
      return {
        state: finished.error || finished.data !== true
          ? "lease_unsettled"
          : success
          ? "done"
          : "retry",
      };
    }),
  );
  return json({
    processed: outcomes.length,
    outcomes,
    erased_accounts: erased,
    orphan_uploads: orphanOutcomes,
    private_media_cleanup: privateMediaOutcomes,
  });
});
