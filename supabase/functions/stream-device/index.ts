import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { StreamServer } from "../_shared/stream_server.ts";
import { BodyTooLarge, readBoundedBody } from "../_shared/bounded_body.ts";
import { streamDeviceInput, streamPushProvider } from "./contract.ts";

const headers = {
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const json = (value: unknown, status = 200) =>
  Response.json(value, { status, headers });
Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers });
  }
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "authentication_required" }, 401);
  }
  let input: ReturnType<typeof streamDeviceInput>;
  try {
    input = streamDeviceInput(
      JSON.parse(new TextDecoder().decode(await readBoundedBody(req, 8192))),
    );
  } catch (e) {
    return json({
      error: e instanceof BodyTooLarge
        ? "device_body_too_large"
        : "invalid_device",
    }, e instanceof BodyTooLarge ? 413 : 400);
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
  const { data: identity, error: identityError } = await client.auth.getUser();
  if (identityError || !identity.user) {
    return json({ error: "authentication_required" }, 401);
  }
  const actor = identity.user.id;
  const key = Deno.env.get("STREAM_API_KEY"),
    secret = Deno.env.get("STREAM_API_SECRET");
  if (!key || !secret) return json({ error: "stream_not_configured" }, 503);
  const admin = createClient(
    url,
    Deno.env.get("BLAB_SUPABASE_SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const { data: lease, error: reserveError } = await admin.rpc(
    "reserve_stream_push_device",
    {
      p_actor: actor,
      p_token: input.token,
      p_action: input.action,
      p_previews: input.previewsEnabled,
    },
  );
  if (reserveError) return json({ error: "device_not_available" }, 403);
  if (lease?.status === "not_owned") return json({ ok: true });
  if (lease?.status !== "reserved") {
    return json({ error: "device_operation_in_flight" }, 409);
  }
  const server = new StreamServer(key, secret);
  let success = false;
  try {
    // Remove old-account and old-provider routes before publishing a replacement.
    for (const userId of new Set<string>([actor, ...lease.previousOwners])) {
      try {
        await server.request("devices", undefined, {
          method: "DELETE",
          query: { id: input.token, user_id: userId },
        });
      } catch (e) {
        if (!(e instanceof Error) || e.message !== "stream_http_404") throw e;
      }
    }
    if (input.action === "register") {
      const { data: profile, error: profileError } = await client.from(
        "profiles",
      ).select("display_name").eq("id", actor).single();
      if (profileError || !profile) throw new Error("profile_unavailable");
      await server.request("users", {
        users: {
          [actor]: {
            id: actor,
            role: "user",
            name: profile.display_name,
            privacy_settings: {
              read_receipts: { enabled: false },
              delivery_receipts: { enabled: false },
            },
          },
        },
      });
      await server.request("devices", {
        id: input.token,
        user_id: actor,
        push_provider: "firebase",
        push_provider_name: streamPushProvider(input.previewsEnabled),
      });
    }
    success = true;
  } catch { /* No device token or provider body enters logs. */ }
  const { data: finished, error: finishError } = await admin.rpc(
    "finish_stream_push_device",
    {
      p_actor: actor,
      p_token: input.token,
      p_lease: lease.leaseToken,
      p_success: success,
    },
  );
  if (finishError || finished !== true) {
    return json({ error: "device_completion_unavailable" }, 503);
  }
  return success
    ? json({ ok: true })
    : json({ error: "push_provider_unavailable" }, 503);
});
