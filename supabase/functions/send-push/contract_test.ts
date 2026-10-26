import {
  buildCustomAndroidFcmMessage,
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
  assert(
    eventIdFromWebhook({ eventId: event.event_id }) === event.event_id,
    "direct",
  );
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

Deno.test("notification identity isolates account, chat and read message", () => {
  const value = buildFcmMessage(
    { ...event, message_id: "read-message" },
    "token",
    false,
  );
  assert(
    value.message.android.notification.tag ===
      `blab:${event.recipient_id}:${event.chat_id}:read-message`,
    "precise cancellation tag",
  );
  assert(
    value.message.data.messageId === "read-message",
    "message identity retained with previews off",
  );
});

Deno.test("photo previews identify media in each recipient interface language", () => {
  for (
    const [language, photo] of Object.entries({
      en: "Photo",
      de: "Foto",
      es: "Foto",
      uk: "Фото",
    })
  ) {
    for (const original_body of ["", null, "   "]) {
      const payload = buildFcmMessage(
        {
          ...event,
          interface_language: language,
          message_type: "image",
          original_body,
        },
        "token",
        true,
      );
      assert(payload.message.notification.title === "Alice", "sender title");
      assert(
        payload.message.notification.body === photo,
        `${language} photo label`,
      );
    }
  }
});

Deno.test("captioned photos retain authored caption; hidden previews reveal no media type", () => {
  const photo = {
    ...event,
    message_type: "image" as const,
    interface_language: "uk",
  };
  assert(
    buildFcmMessage(photo, "token", true).message.notification.body ===
      "Фото: Hello Bob How are you?",
    "localized photo and authored caption",
  );
  const hidden = buildFcmMessage(photo, "token", false);
  assert(hidden.message.notification.title === "Blab", "private title");
  assert(
    hidden.message.notification.body === "У вас нове повідомлення",
    "private copy unchanged",
  );
  const text = buildFcmMessage(
    { ...event, original_body: "", interface_language: "uk" },
    "token",
    true,
  );
  assert(
    text.message.notification.body === "У вас нове повідомлення",
    "empty text is not a photo",
  );
});

Deno.test("opt-in Android chat uses data only, with bound identity and original preview", () => {
  const value = buildCustomAndroidFcmMessage(
    { ...event, message_id: "message-id" },
    "token",
    true,
  ).message;
  assert(
    !("notification" in value),
    "must not let OS pre-render a tinted notification",
  );
  assert(
    !("notification" in value.android),
    "no Android OS notification block",
  );
  assert(value.android.priority === "high", "background delivery priority");
  assert(
    value.data.title === "Alice" &&
      value.data.body === "Hello Bob How are you?",
    "authored preview",
  );
  assert(
    value.data.receiverId === event.recipient_id &&
      value.data.chatId === event.chat_id,
    "bound routing",
  );
  assert(
    value.data.androidPresentation === "blab_custom_v1",
    "versioned client contract",
  );
});
Deno.test("opt-in Android private payload includes no person or authored preview", () => {
  const value = buildCustomAndroidFcmMessage(
    { ...event, interface_language: "uk" },
    "token",
    false,
  ).message;
  const data = JSON.stringify(value.data);
  assert(
    !data.includes("Alice") && !data.includes("Hello"),
    "no private identity/text in data",
  );
  assert(
    value.data.previewsEnabled === "false" &&
      value.data.interfaceLanguage === "uk",
    "privacy/locale available offline",
  );
  assert(value.data.title === "Blab", "generic identity");
});
