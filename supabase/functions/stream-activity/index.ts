import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { StreamServer } from "../_shared/stream_server.ts";
import { streamBodyHash } from "../stream-events/contract.ts";
const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Cache-Control": "no-store",
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
    !input || typeof input.chatId !== "string" || !uuid.test(input.chatId) ||
    !["read", "react", "unreact", "typing.start", "typing.stop"].includes(
      String(input.action),
    )
  ) return json({ error: "invalid_activity" }, 400);
  if (input.emoji !== undefined && typeof input.emoji !== "string") {
    return json({ error: "invalid_reaction" }, 400);
  }
  const ids = input.messageIds ?? [];
  if (
    !Array.isArray(ids) || ids.length > 50 ||
    ids.some((id) => typeof id !== "string" || !uuid.test(id))
  ) return json({ error: "invalid_messages" }, 400);
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
  const { data: allowed, error: allowedError } = await client.rpc(
    "authorize_stream_activity",
    {
      p_chat_id: input.chatId,
      p_action: input.action,
      p_message_ids: ids,
      p_emoji: input.emoji ?? null,
    },
  );
  if (allowedError) {
    return json(
      { error: "activity_not_available" },
      allowedError.code === "42501" ? 403 : 409,
    );
  }
  if (allowed?.status === "ignored") return json({ status: "ignored" });
  if (
    allowed?.status !== "authorized" || allowed.actorId !== identity.user.id
  ) return json({ error: "activity_not_available" }, 403);
  const actor = identity.user.id;
  const server = new StreamServer(key, secret);
  const admin = createClient(
    url,
    Deno.env.get("BLAB_SUPABASE_SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  try {
    if (String(input.action).startsWith("typing.")) {
      await server.request(`channels/blab/${input.chatId}/event`, {
        event: { type: input.action, user: { id: actor } },
      });
      return json({ status: "sent" });
    }
    // Native visible-message batches are small; bound parallel mutation work.
    const messageIds = allowed.messageIds as string[];
    for (let start = 0; start < messageIds.length; start += 8) {
      await Promise.all(
        messageIds.slice(start, start + 8).map(async (id) => {
          const canonical = (await server.request(`messages/${id}`, undefined, {
            query: { show_deleted_message: "true" },
          })).message as Record<string, unknown>;
          if (
            canonical.cid !== `blab:${input.chatId}` || canonical.deleted_at
          ) throw new Error("activity_message_not_available");
          if (input.action === "read") {
            if ((canonical.user as { id?: string }).id === actor) return;
            const reads = canonical.blab_read_by;
            if (!Array.isArray(reads) || !reads.includes(actor)) {
              await server.request(`messages/${id}`, {
                set: {
                  blab_read_by: [actor],
                  blab_read_at: new Date().toISOString(),
                },
                user_id: actor,
              }, { method: "PUT" });
            }
          } else if (input.action === "react") {
            const emoji = String(input.emoji);
            const type = "blab_" +
              (await streamBodyHash(new TextEncoder().encode(emoji))).slice(
                0,
                24,
              );
            await server.request(`messages/${id}/reaction`, {
              reaction: {
                type,
                blab_emoji: emoji,
                emoji_code: emoji,
                user_id: actor,
                score: 1,
              },
              enforce_unique: true,
            });
          } else {
            const reactions = Array.isArray(canonical.latest_reactions)
              ? canonical.latest_reactions as Array<Record<string, unknown>>
              : [];
            for (const reaction of reactions) {
              if (
                reaction.user_id === actor ||
                (reaction.user as { id?: string } | undefined)?.id === actor
              ) {
                await server.request(
                  `messages/${id}/reaction/${
                    encodeURIComponent(String(reaction.type))
                  }`,
                  undefined,
                  { method: "DELETE", query: { user_id: actor } },
                );
              }
            }
          }
          const event = {
            type: "message.updated",
            cid: `blab:${input.chatId}`,
            created_at: new Date().toISOString(),
            message: { id },
          };
          const eventId = `activity:${crypto.randomUUID()}`;
          const queued = await admin.rpc("enqueue_stream_message_event", {
            p_event_id: eventId,
            p_body_hash: await streamBodyHash(
              new TextEncoder().encode(eventId),
            ),
            p_event: event,
          });
          if (queued.error) throw new Error("activity_recovery_pending");
        }),
      );
    }
    return json({ status: "accepted" });
  } catch {
    return json({ error: "activity_unavailable" }, 503);
  }
});
