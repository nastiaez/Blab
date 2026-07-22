import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import {
  buildFcmMessage,
  type ClaimedPushEvent,
  eventIdFromWebhook,
  fcmErrorCode,
  isStaleFcmToken,
} from "./contract.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const PUSH_WEBHOOK_SECRET = Deno.env.get("PUSH_WEBHOOK_SECRET") ?? "";
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID") ?? "";
const FIREBASE_CLIENT_EMAIL = Deno.env.get("FIREBASE_CLIENT_EMAIL") ?? "";
const FIREBASE_PRIVATE_KEY = (Deno.env.get("FIREBASE_PRIVATE_KEY") ?? "")
  .replaceAll("\\n", "\n");

let cachedAccessToken: { value: string; expiresAt: number } | null = null;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function base64Url(value: Uint8Array | string): string {
  const bytes = typeof value === "string"
    ? new TextEncoder().encode(value)
    : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

function privateKeyBytes(pem: string): Uint8Array {
  const body = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const binary = atob(body);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

async function firebaseAccessToken(): Promise<string> {
  const nowMs = Date.now();
  if (cachedAccessToken !== null && cachedAccessToken.expiresAt > nowMs + 60_000) {
    return cachedAccessToken.value;
  }
  const now = Math.floor(nowMs / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(JSON.stringify({
    iss: FIREBASE_CLIENT_EMAIL,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    privateKeyBytes(FIREBASE_PRIVATE_KEY),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(unsigned),
    ),
  );
  const assertion = `${unsigned}.${base64Url(signature)}`;
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const body = await response.json() as {
    access_token?: unknown;
    expires_in?: unknown;
    error?: unknown;
  };
  if (!response.ok) {
    const providerCode = typeof body.error === "string"
      ? body.error.replace(/[^a-z0-9_-]/gi, "_").slice(0, 40)
      : "unknown";
    throw new Error(`oauth_${response.status}_${providerCode}`);
  }
  if (typeof body.access_token !== "string") throw new Error("oauth_invalid");
  const expiresIn = typeof body.expires_in === "number" ? body.expires_in : 3600;
  cachedAccessToken = {
    value: body.access_token,
    expiresAt: nowMs + expiresIn * 1000,
  };
  return body.access_token;
}

function safeFailureCode(error: unknown): string {
  if (!(error instanceof Error)) return "firebase_auth_failed";
  if (/^oauth_(?:[1-5][0-9]{2}_[a-z0-9_-]+|invalid)$/i.test(error.message)) {
    return error.message.slice(0, 80);
  }
  return "firebase_key_invalid";
}

async function completeClaimedEvent(
  supabase: ReturnType<typeof createClient>,
  eventId: string,
  lastError: string,
): Promise<void> {
  const { error } = await supabase.rpc("complete_push_notification_event", {
    p_event_id: eventId,
    p_last_error: lastError,
  });
  if (error) console.error("push_event_completion_failed");
}

async function recordAuthenticationFailure(
  supabase: ReturnType<typeof createClient>,
  eventId: string,
  tokens: Array<Record<string, unknown>>,
  failureCode: string,
): Promise<void> {
  for (const device of tokens) {
    if (typeof device.token !== "string") continue;
    const tokenHash = await sha256(device.token);
    const { data: reserved, error: reserveError } = await supabase.rpc(
      "reserve_push_notification_delivery",
      { p_event_id: eventId, p_token_hash: tokenHash },
    );
    if (reserveError || reserved !== true) continue;
    await supabase.rpc("finish_push_notification_delivery", {
      p_event_id: eventId,
      p_token_hash: tokenHash,
      p_status: "failed",
      p_provider_code: failureCode,
    });
  }
  await completeClaimedEvent(supabase, eventId, failureCode);
}

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (
    PUSH_WEBHOOK_SECRET.length < 24 ||
    request.headers.get("x-blab-push-secret") !== PUSH_WEBHOOK_SECRET
  ) {
    return json({ error: "unauthorized" }, 401);
  }
  if (
    !FIREBASE_PROJECT_ID || !FIREBASE_CLIENT_EMAIL ||
    !FIREBASE_PRIVATE_KEY.includes("BEGIN PRIVATE KEY")
  ) {
    return json({ error: "push_not_configured" }, 503);
  }

  let input: unknown;
  try {
    input = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const eventId = eventIdFromWebhook(input);
  if (eventId === null) return json({ error: "invalid_event" }, 400);

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: claimedRows, error: claimError } = await supabase.rpc(
    "claim_push_notification_event",
    { p_event_id: eventId },
  );
  if (claimError) return json({ error: "claim_failed" }, 500);
  const claimed = Array.isArray(claimedRows)
    ? claimedRows[0] as ClaimedPushEvent | undefined
    : undefined;
  if (claimed === undefined) return json({ status: "already_processed" });

  const { data: tokens, error: tokenError } = await supabase
    .from("push_device_tokens")
    .select("token,previews_enabled")
    .eq("user_id", claimed.recipient_id);
  if (tokenError) {
    await completeClaimedEvent(supabase, eventId, "token_lookup_failed");
    return json({ error: "token_lookup_failed" }, 500);
  }
  if (tokens === null || tokens.length === 0) {
    await supabase.rpc("complete_push_notification_event", {
      p_event_id: eventId,
      p_last_error: null,
    });
    return json({ status: "processed", attempted: 0, failures: 0 });
  }

  let accessToken: string;
  try {
    accessToken = await firebaseAccessToken();
  } catch (error) {
    const failureCode = safeFailureCode(error);
    console.error("firebase_auth_failed", { code: failureCode });
    await recordAuthenticationFailure(
      supabase,
      eventId,
      tokens as Array<Record<string, unknown>>,
      failureCode,
    );
    return json({ error: "firebase_auth_failed" }, 502);
  }

  let failures = 0;
  for (const device of tokens ?? []) {
    const token = device.token as string;
    const tokenHash = await sha256(token);
    const { data: reserved, error: reserveError } = await supabase.rpc(
      "reserve_push_notification_delivery",
      { p_event_id: eventId, p_token_hash: tokenHash },
    );
    if (reserveError || reserved !== true) continue;

    let status = "failed";
    let providerCode = "unreachable";
    try {
      const fcm = await fetch(
        `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(FIREBASE_PROJECT_ID)}/messages:send`,
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify(
            buildFcmMessage(claimed, token, device.previews_enabled === true),
          ),
        },
      );
      if (fcm.ok) {
        status = "sent";
        providerCode = "ok";
      } else {
        let errorBody: unknown = null;
        try {
          errorBody = await fcm.json();
        } catch {
          // Keep only the HTTP status; provider response content is not logged.
        }
        providerCode = fcmErrorCode(errorBody);
        if (isStaleFcmToken(providerCode)) {
          status = "stale";
          await supabase.from("push_device_tokens").delete().eq("token", token);
        } else {
          failures++;
        }
      }
    } catch {
      failures++;
    }
    await supabase.rpc("finish_push_notification_delivery", {
      p_event_id: eventId,
      p_token_hash: tokenHash,
      p_status: status,
      p_provider_code: providerCode,
    });
  }

  await supabase.rpc("complete_push_notification_event", {
    p_event_id: eventId,
    p_last_error: failures === 0 ? null : `${failures} delivery failures`,
  });
  return json({ status: "processed", attempted: tokens?.length ?? 0, failures });
});
