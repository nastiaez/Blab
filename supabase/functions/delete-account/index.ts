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
import { StreamServer } from "../_shared/stream_server.ts";
import { deactivateStreamAccount } from "../_shared/stream_account_erasure.ts";
import { isMissingPrivateObject } from "../_shared/private_media_cleanup.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("BLAB_SUPABASE_ANON_KEY") ??
  Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY =
  Deno.env.get("BLAB_SUPABASE_SERVICE_ROLE_KEY") ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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

  const key = Deno.env.get("STREAM_API_KEY"),
    secret = Deno.env.get("STREAM_API_SECRET");
  let vendor: StreamServer | null = null;
  let deactivated = false;
  if (key && secret) {
    const queued = await admin.rpc("queue_stream_account_erasure", {
      p_user_id: userId,
    });
    if (queued.error) return json({ error: "delete_failed" }, 503);
    vendor = new StreamServer(key, secret);
    try {
      deactivated = await deactivateStreamAccount(vendor, userId);
    } catch {
      // Do not delete auth while a still-valid vendor session could survive.
      return json({ error: "delete_failed" }, 503);
    }
  }

  // Record cleanup first; remove old client-owned files before auth deletion.
  // Interrupted/new uploads remain durably queued for the recovery worker.
  const queuedPhotos = await admin.rpc("queue_account_private_media_cleanup", {
    p_actor_id: userId,
  });
  if (queuedPhotos.error) return json({ error: "delete_failed" }, 503);
  try {
    const rows = (queuedPhotos.data ?? []) as Array<
      { bucket_id: string; object_path: string }
    >;
    for (const bucket of ["message-media", "stream-private-media"]) {
      const paths = rows.filter((row) => row.bucket_id === bucket).map((row) =>
        row.object_path
      );
      if (!paths.length) continue;
      const removed = await admin.storage.from(bucket).remove(paths);
      if (removed.error) throw removed.error;
      for (const path of paths) {
        const probe = await admin.storage.from(bucket).download(path);
        if (!isMissingPrivateObject(probe.error)) {
          throw new Error("photo_removal_unconfirmed");
        }
      }
    }
  } catch {
    return json({ error: "delete_failed" }, 503);
  }
  const { error: delErr } = await admin.auth.admin.deleteUser(userId);
  if (delErr) {
    if (vendor && deactivated) {
      try {
        await vendor.request(`users/${userId}/reactivate`, {});
      } catch { /* Safe to retry deletion. */ }
    }
    console.error("deleteUser failed", { userId, message: delErr.message });
    return json({ error: "delete_failed" }, 500);
  }

  return json({ ok: true });
});
