import { parseMentions } from "./mentions.ts";
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import type { EdgeRuntime as EdgeRuntimeType } from "jsr:@supabase/functions-js/edge-runtime.d.ts";
declare const EdgeRuntime: typeof EdgeRuntimeType;
import { createClient } from "jsr:@supabase/supabase-js@2";
import { StreamServer } from "../_shared/stream_server.ts";
import { streamBodyHash } from "../stream-events/contract.ts";

const headers = {
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  Response.json(body, { status, headers });
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers });
  }
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "authentication_required" }, 401);
  }
  let input: Record<string, unknown>;
  try {
    input = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (
    !input || typeof input !== "object" ||
    [input.requestId, input.chatId, input.messageId].some((value) =>
      typeof value !== "string" || !uuid.test(value)
    ) ||
    !["send", "send_image", "edit", "delete", "restore"].includes(
      String(input.action),
    )
  ) return json({ error: "invalid_command" }, 400);
  if (input.body !== undefined && typeof input.body !== "string") {
    return json({ error: "invalid_body" }, 400);
  }
  if (
    input.replyId !== undefined && input.replyId !== null &&
    (typeof input.replyId !== "string" || !uuid.test(input.replyId))
  ) return json({ error: "invalid_reply" }, 400);
  let mentions;
  try { mentions = parseMentions(input.mentions, String(input.body ?? "")); } catch { return json({ error: "invalid_mentions" }, 400); }
  const key = Deno.env.get("STREAM_API_KEY"),
    secret = Deno.env.get("STREAM_API_SECRET");
  if (!key || !secret) return json({ error: "stream_not_configured" }, 503);
  const url = Deno.env.get("SUPABASE_URL")!;
  const client = createClient(
    url,
    Deno.env.get("BLAB_SUPABASE_ANON_KEY") ??
      Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
  const { data: identity, error: identityError } = await client.auth.getUser();
  if (identityError || !identity.user) {
    return json({ error: "authentication_required" }, 401);
  }
  const { data: command, error: commandError } = await client.rpc(
    "authorize_stream_message_command",
    {
      p_request_id: input.requestId,
      p_chat_id: input.chatId,
      p_message_id: input.messageId,
      p_action: input.action,
      p_body: input.body ?? null,
      p_reply_id: input.replyId ?? null,
      p_mentions: mentions,
    },
  );
  if (commandError) {
    return json(
      { error: "command_not_available" },
      commandError.code === "42501" ? 403 : 409,
    );
  }
  if (command?.status === "done") return json(command.result);
  if (
    command?.status !== "authorized" || command.actorId !== identity.user.id
  ) return json({ error: "command_in_flight" }, 409);
  const admin = createClient(
    url,
    Deno.env.get("BLAB_SUPABASE_SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const server = new StreamServer(key, secret);
  let result: Record<string, unknown> | null = null;
  try {
    let canonical: Record<string, unknown> | null = null;
    try {
      canonical =
        (await server.request(`messages/${input.messageId}`, undefined, {
          query: { show_deleted_message: "true" },
        })).message as Record<string, unknown>;
    } catch (error) {
      if (
        !["send", "send_image"].includes(String(input.action)) ||
        !(error instanceof Error) ||
        error.message !== "stream_http_404"
      ) throw error;
    }
    if (
      canonical &&
      (canonical.cid !== `blab:${input.chatId}` ||
        (canonical.user as { id?: unknown })?.id !== identity.user.id)
    ) throw new Error("message_identity_mismatch");
    if (input.action === "send" || input.action === "send_image") {
      if (canonical) {
        if (
          canonical.text !== input.body || canonical.deleted_at ||
          JSON.stringify(canonical.blab_mentions ?? []) !== JSON.stringify(mentions) ||
          (canonical.quoted_message_id ?? null) !== (input.replyId ?? null)
        ) throw new Error("idempotency_conflict");
        if (
          input.action === "send_image" &&
          !(canonical.attachments as Array<Record<string, unknown>> | undefined)
            ?.some((attachment) =>
              attachment.blab_asset_id === input.messageId &&
              attachment.blab_source_hash ===
                (command.attachment as Record<string, unknown>)
                  ?.blab_source_hash
            )
        ) throw new Error("image_identity_conflict");
      } else {
        canonical =
          (await server.request(`channels/blab/${input.chatId}/message`, {
            message: {
              id: input.messageId,
              user_id: identity.user.id,
              text: input.body,
              blab_mentions: mentions,
              blab_languages_matched_at_send:
                command.languagesMatchedAtSend === true,
              ...(input.replyId ? { quoted_message_id: input.replyId } : {}),
              ...(input.action === "send_image"
                ? { attachments: [command.attachment] }
                : {}),
            },
            skip_enrich_url: true,
          })).message as Record<string, unknown>;
      }
    } else if (input.action === "edit") {
      canonical = (await server.request(`messages/${input.messageId}`, {
        set: { text: input.body, blab_mentions: mentions },
        user_id: identity.user.id,
        skip_enrich_url: true,
      }, { method: "PUT" })).message as Record<string, unknown>;
    } else if (input.action === "delete") {
      if (!canonical?.deleted_at) {
        await server.request(`messages/${input.messageId}`, undefined, {
          method: "DELETE",
          query: { hard: "false", deleted_by: identity.user.id },
        });
      }
    } else if (input.action === "restore") {
      if (canonical?.deleted_at) {
        canonical =
          (await server.request(`messages/${input.messageId}/undelete`, {
            undeleted_by: identity.user.id,
          })).message as Record<string, unknown>;
      }
    }
    if (
      !canonical || typeof canonical.created_at !== "string" ||
      canonical.type === "error"
    ) throw new Error("missing_canonical_acknowledgment");
    result = { id: input.messageId, createdAt: canonical.created_at };
  } catch {
    result = null;
  }
  if (result) {
    // Retain recovery before acknowledging the command. This also covers a
    // lost public webhook or a quoted source not yet projected locally.
    const event = {
      type: ["send", "send_image"].includes(String(input.action))
        ? "message.new"
        : input.action === "delete"
        ? "message.deleted"
        : "message.updated",
      cid: `blab:${input.chatId}`,
      created_at: new Date().toISOString(),
      message: { id: input.messageId },
    };
    const queued = await admin.rpc("enqueue_stream_message_event", {
      p_event_id: `command:${input.requestId}`,
      p_body_hash: await streamBodyHash(
        new TextEncoder().encode(JSON.stringify({ command: input.requestId })),
      ),
      p_event: event,
    });
    if (queued.error) result = null;
  }
  const finished = await admin.rpc("finish_stream_message_command", {
    p_request_id: input.requestId,
    p_lease_token: command.leaseToken,
    p_result: result,
  });
  if (finished.error || finished.data !== true) {
    return json({ error: "delivery_recovery_pending" }, 503);
  }
  if (result) {
    // Best-effort eager preparation; the signed durable webhook is recovery.
    // Stream has already delivered the original. Never await AI on this path.
    EdgeRuntime.waitUntil((async () => {
      try {
        const current = await server.request(
          `messages/${input.messageId}`,
          undefined,
          { query: { show_deleted_message: "true" } },
        );
        await admin.rpc("apply_stream_message_snapshot", {
          p_chat_id: input.chatId,
          p_snapshot: current.message,
        });
      } catch {
        // The registered webhook/recovery worker retries canonical ingestion.
      }
    })());
  }
  return result ? json(result) : json({ error: "message_unavailable" }, 503);
});
