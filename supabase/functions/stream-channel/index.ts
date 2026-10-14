import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { StreamServer } from "../_shared/stream_server.ts";

const headers = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers });
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers });
  }
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "authentication_required" }, 401);
  }
  let input: unknown;
  try {
    input = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const chatId = input !== null && typeof input === "object"
    ? (input as { chatId?: unknown }).chatId
    : null;
  if (typeof chatId !== "string" || !uuid.test(chatId)) {
    return json({ error: "invalid_chat" }, 400);
  }
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
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) {
    return json({ error: "authentication_required" }, 401);
  }
  const userId = data.user.id;
  const { data: active, error: activeError } = await client.rpc(
    "is_account_active",
    { target_user_id: userId },
  );
  if (activeError) return json({ error: "account_state_unavailable" }, 503);
  if (active !== true) return json({ error: "account_not_available" }, 403);
  // Existing RLS-visible chat identity is required; caller cannot add members.
  const { data: visible, error: accessError } = await client.from("chat_list")
    .select("chat_id").eq("viewer_id", userId).eq("chat_id", chatId)
    .maybeSingle();
  if (accessError || !visible) {
    return json({ error: "chat_not_available" }, 403);
  }
  const { data: transport, error: transportError } = await client.from(
    "chat_message_transports",
  ).select("provider,migration_state").eq("chat_id", chatId).maybeSingle();
  if (transportError) return json({ error: "chat_state_unavailable" }, 503);
  if (
    transport?.provider !== "stream" || transport.migration_state === "rollback"
  ) {
    return json({ error: "stream_not_enabled" }, 409);
  }
  const admin = createClient(
    url,
    Deno.env.get("BLAB_SUPABASE_SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const { data: members, error: memberError } = await admin.from("chat_members")
    .select("user_id").eq("chat_id", chatId);
  if (
    memberError || !members || members.length !== 2 ||
    !members.some((m) => m.user_id === userId)
  ) return json({ error: "chat_not_available" }, 403);
  const ids = members.map((m) => m.user_id as string);
  const { data: profiles, error: profileError } = await client.from("profiles")
    .select("id,display_name").in("id", ids);
  const { data: blocked, error: blockError } = await client.rpc(
    "is_blocked_in_chat",
    { p_chat_id: chatId },
  );
  if (profileError || blockError) {
    return json({ error: "chat_state_unavailable" }, 503);
  }
  const key = Deno.env.get("STREAM_API_KEY"),
    secret = Deno.env.get("STREAM_API_SECRET");
  if (!key || !secret) return json({ error: "stream_not_configured" }, 503);
  try {
    const server = new StreamServer(key, secret);
    await server.request("users", {
      users: Object.fromEntries(
        (profiles ?? []).map(
          (p) => [p.id, { id: p.id, name: p.display_name ?? "", role: "user" }],
        ),
      ),
    });
    await server.request(`channels/blab/${chatId}/query`, {
      data: { members: ids, created_by_id: userId, blab_chat_id: chatId },
      state: false,
      watch: false,
      presence: false,
    });
    // Blocking remains symmetric for sending, while existing history is readable.
    await server.request(`channels/blab/${chatId}`, {
      data: {
        frozen: blocked === true,
        blab_chat_id: chatId,
        config_overrides: {
          grants: {
            channel_member: [
              "!create-message",
              "!create-reply",
              "!update-message-owner",
              "!delete-message-owner",
              "!create-reaction",
              "!delete-reaction-owner",
              "!create-attachment",
              "!upload-attachment",
              "!delete-attachment-owner",
            ],
          },
        },
      },
    });
    return json({ channelType: "blab", channelId: chatId });
  } catch {
    return json({ error: "stream_unavailable" }, 503);
  }
});
