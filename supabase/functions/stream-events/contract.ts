const encoder = new TextEncoder();
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function verifyStreamSignature(
  body: Uint8Array,
  signature: string | null,
  secret: string,
): Promise<boolean> {
  if (!signature || !/^[0-9a-f]{64}$/i.test(signature) || !secret) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const bytes = Uint8Array.from(
    signature.match(/../g)!,
    (value) => parseInt(value, 16),
  );
  return await crypto.subtle.verify("HMAC", key, bytes, new Uint8Array(body));
}
export async function streamBodyHash(body: Uint8Array): Promise<string> {
  const digest = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new Uint8Array(body)),
  );
  return Array.from(digest, (byte) => byte.toString(16).padStart(2, "0")).join(
    "",
  );
}
export function retainedStreamEvent(
  input: unknown,
): Record<string, unknown> | null {
  if (typeof input !== "object" || input === null || Array.isArray(input)) {
    return null;
  }
  const event = input as Record<string, unknown>;
  if (
    ![
      "message.new",
      "message.updated",
      "message.deleted",
      "reaction.new",
      "reaction.updated",
      "reaction.deleted",
    ].includes(
      String(event.type),
    )
  ) return null;
  if (
    typeof event.cid !== "string" || !event.cid.startsWith("blab:") ||
    !uuid.test(event.cid.slice(5))
  ) return null;
  const message = event.message as Record<string, unknown> | null;
  if (!message || typeof message.id !== "string" || !uuid.test(message.id)) {
    throw new Error("invalid_message");
  }
  if (
    typeof event.created_at !== "string" ||
    !Number.isFinite(Date.parse(event.created_at))
  ) throw new Error("invalid_event_time");
  // Persist only reconciliation identity. The worker fetches current canonical
  // data from Stream; retries/late edits cannot resurrect an obsolete body.
  return {
    type: String(event.type).startsWith("reaction.")
      ? "message.updated"
      : event.type,
    cid: event.cid,
    created_at: event.created_at,
    message: { id: message.id },
  };
}
