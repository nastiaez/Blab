import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { BodyTooLarge, readBoundedBody } from "../_shared/bounded_body.ts";
import { decodeStreamWebhookBody, UnsupportedWebhookEncoding } from "./body.ts";
import {
  retainedStreamEvent,
  streamBodyHash,
  verifyStreamSignature,
} from "./contract.ts";

const json = (body: unknown, status = 200) =>
  Response.json(body, { status, headers: { "Cache-Control": "no-store" } });
Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  const key = Deno.env.get("STREAM_API_KEY"),
    secret = Deno.env.get("STREAM_API_SECRET");
  if (!key || !secret) return json({ error: "stream_not_configured" }, 503);
  if (request.headers.get("X-Api-Key") !== key) {
    return json({ error: "invalid_app" }, 401);
  }
  if (Number(request.headers.get("Content-Length")) > 262144) {
    return json({ error: "event_too_large" }, 413);
  }
  let body: Uint8Array;
  try {
    body = await decodeStreamWebhookBody(
      await readBoundedBody(request, 262144),
      request.headers.get("Content-Encoding"),
    );
  } catch (error) {
    if (error instanceof UnsupportedWebhookEncoding) {
      return json({ error: "unsupported_encoding" }, 415);
    }
    return json({
      error: error instanceof BodyTooLarge ? "event_too_large" : "invalid_body",
    }, error instanceof BodyTooLarge ? 413 : 400);
  }
  if (
    !await verifyStreamSignature(
      body,
      request.headers.get("X-Signature"),
      secret,
    )
  ) return json({ error: "invalid_signature" }, 401);
  let event: Record<string, unknown> | null;
  try {
    event = retainedStreamEvent(JSON.parse(new TextDecoder().decode(body)));
  } catch {
    return json({ error: "invalid_event" }, 400);
  }
  if (!event) return json({ accepted: true, ignored: true });
  const hash = await streamBodyHash(body);
  const eventId = request.headers.get("X-Webhook-Id") ?? hash;
  if (eventId.length > 200 || eventId.length === 0) {
    return json({ error: "invalid_event_id" }, 400);
  }
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("BLAB_SUPABASE_SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const { data, error } = await admin.rpc("enqueue_stream_message_event", {
    p_event_id: eventId,
    p_body_hash: hash,
    p_event: event,
  });
  if (error) return json({ error: "event_queue_unavailable" }, 503);
  // Acknowledge durable storage, not completion of translation or metadata.
  return json({ accepted: true, state: data });
});
