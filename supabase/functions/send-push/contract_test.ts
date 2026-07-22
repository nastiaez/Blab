import {
  buildFcmMessage,
  eventIdFromWebhook,
  fcmErrorCode,
  isStaleFcmToken,
  MAX_PREVIEW_GRAPHEMES,
  truncatePreview,
} from "./contract.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

const event = {
  event_id: "10000000-0000-4000-8000-000000000001",
  event_type: "chat_message" as const,
  recipient_id: "10000000-0000-4000-8000-000000000002",
  actor_name: "Alice",
  interface_language: "en",
  chat_id: "10000000-0000-4000-8000-000000000003",
  original_body: "Hello   Bob\nHow are you?",
};

Deno.test("accepts direct and Database Webhook event IDs", () => {
  assert(eventIdFromWebhook({ eventId: event.event_id }) === event.event_id, "direct");
  assert(
    eventIdFromWebhook({ record: { id: event.event_id } }) === event.event_id,
    "webhook record",
  );
  assert(eventIdFromWebhook({ record: { id: "bad" } }) === null, "invalid");
});

Deno.test("preview payload contains original text but no translation fields", () => {
  const payload = buildFcmMessage(event, "device-token", true);
  assert(payload.message.notification.title === "Alice", "sender title");
  assert(
    payload.message.notification.body === "Hello Bob How are you?",
    "normalized original",
  );
  assert(payload.message.data.chatId === event.chat_id, "chat route");
  assert(!JSON.stringify(payload).includes("translation"), "no translation");
});

Deno.test("disabled previews and invite claims use generic copy", () => {
  const hidden = buildFcmMessage(event, "device-token", false);
  assert(hidden.message.notification.title === "Blab", "generic title");
  assert(
    hidden.message.notification.body === "You have a new message",
    "generic message",
  );
  const invite = buildFcmMessage(
    { ...event, event_type: "invite_claimed", original_body: null },
    "device-token",
    true,
  );
  assert(invite.message.notification.title === "Blab", "invite title");
  assert(
    invite.message.notification.body === "Your friend joined the chat",
    "invite body",
  );
});

Deno.test("generic copy follows the recipient interface language", () => {
  const payload = buildFcmMessage(
    { ...event, interface_language: "de" },
    "device-token",
    false,
  );
  assert(
    payload.message.notification.body === "Du hast eine neue Nachricht",
    "German generic body",
  );
});

Deno.test("long previews are grapheme-safe and bounded", () => {
  const family = "👨‍👩‍👧‍👦";
  const preview = truncatePreview(family.repeat(MAX_PREVIEW_GRAPHEMES + 5));
  const count = [...new Intl.Segmenter(undefined, { granularity: "grapheme" })
    .segment(preview)].length;
  assert(count === MAX_PREVIEW_GRAPHEMES, "bounded graphemes");
  assert(preview.endsWith("…"), "ellipsis");
});

Deno.test("only explicit UNREGISTERED responses retire a token", () => {
  const code = fcmErrorCode({
    error: { details: [{ errorCode: "UNREGISTERED" }] },
  });
  assert(code === "UNREGISTERED", "extract error code");
  assert(isStaleFcmToken(code), "unregistered is stale");
  assert(!isStaleFcmToken("INVALID_ARGUMENT"), "payload error is not stale");
});
