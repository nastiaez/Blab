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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers });
  }
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "authentication_required" }, 401);
  }
  const client = createClient(
    Deno.env.get("SUPABASE_URL")!,
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
  // Never accept an identity supplied in the request body.
  const apiKey = Deno.env.get("STREAM_API_KEY");
  const secret = Deno.env.get("STREAM_API_SECRET");
  if (!apiKey || !secret) return json({ error: "stream_not_configured" }, 503);
  const userId = data.user.id;
  const { data: active, error: activeError } = await client.rpc(
    "is_account_active",
    { target_user_id: userId },
  );
  if (activeError) return json({ error: "account_state_unavailable" }, 503);
  if (active !== true) return json({ error: "account_not_available" }, 403);
  const { data: profile, error: profileError } = await client.from("profiles")
    .select("display_name").eq("id", userId).maybeSingle();
  if (profileError || !profile) {
    return json({ error: "profile_unavailable" }, 503);
  }
  const server = new StreamServer(apiKey, secret);
  try {
    await server.request("users", {
      users: {
        [userId]: {
          id: userId,
          role: "user",
          name: profile?.display_name ?? "",
          // Blab owns exact visible-message receipts; disable SDK automatic
          // channel-wide delivery/read reporting independently of that UI.
          privacy_settings: {
            read_receipts: { enabled: false },
            delivery_receipts: { enabled: false },
          },
        },
      },
    });
    const now = Math.floor(Date.now() / 1000);
    return json({
      apiKey,
      userId,
      token: await server.userToken(userId, now),
      expiresAt: now + 3600,
    });
  } catch {
    return json({ error: "stream_unavailable" }, 503);
  }
});
