// PRD US-035: permanently delete the calling user's account.
//
// Flow:
//   1. Read the user's JWT from the Authorization header.
//   2. Verify the JWT with a user-context client (anon key).
//   3. Use a service-role client to call admin.deleteUser(user.id).
//
// Deploy:  supabase functions deploy delete-account
// SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY are auto-injected.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return json({ error: "missing_bearer_token" }, 401);
  }

  // 1. Verify the caller's JWT.
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData.user) {
    return json({ error: "invalid_token" }, 401);
  }
  const userId = userData.user.id;

  // 2. Delete the user via the admin API.
  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { error: delErr } = await admin.auth.admin.deleteUser(userId);
  if (delErr) {
    console.error("deleteUser failed", { userId, message: delErr.message });
    return json({ error: "delete_failed" }, 500);
  }

  return json({ ok: true });
});
