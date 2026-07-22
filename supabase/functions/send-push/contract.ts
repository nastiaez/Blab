export const MAX_PREVIEW_GRAPHEMES = 180;

export type PushEventType = "chat_message" | "invite_claimed";

export interface ClaimedPushEvent {
  event_id: string;
  event_type: PushEventType;
  recipient_id: string;
  actor_name: string;
  interface_language: string;
  chat_id: string;
  original_body: string | null;
}

export interface FcmMessage {
  message: {
    token: string;
    notification: { title: string; body: string };
    data: { type: PushEventType; chatId: string };
    android: {
      priority: "high";
      notification: { channel_id: "messages"; sound: "default" };
    };
  };
}

export function eventIdFromWebhook(value: unknown): string | null {
  if (typeof value !== "object" || value === null) return null;
  const body = value as Record<string, unknown>;
  const direct = body.eventId;
  if (typeof direct === "string" && isUuid(direct)) return direct;
  const record = body.record;
  if (typeof record !== "object" || record === null) return null;
  const id = (record as Record<string, unknown>).id;
  return typeof id === "string" && isUuid(id) ? id : null;
}

export function truncatePreview(value: string): string {
  const normalized = value.replace(/\s+/gu, " ").trim();
  const graphemes = [...new Intl.Segmenter(undefined, {
    granularity: "grapheme",
  }).segment(normalized)].map((part) => part.segment);
  if (graphemes.length <= MAX_PREVIEW_GRAPHEMES) return normalized;
  return `${graphemes.slice(0, MAX_PREVIEW_GRAPHEMES - 1).join("")}…`;
}

export function buildFcmMessage(
  event: ClaimedPushEvent,
  token: string,
  previewsEnabled: boolean,
): FcmMessage {
  const copy = genericCopy(event.interface_language);
  let title = "Blab";
  let body = event.event_type === "invite_claimed"
    ? copy.inviteClaimed
    : copy.newMessage;

  if (
    previewsEnabled && event.event_type === "chat_message" &&
    event.original_body !== null
  ) {
    title = event.actor_name.trim() || "Blab";
    body = truncatePreview(event.original_body) || copy.newMessage;
  }

  return {
    message: {
      token,
      notification: { title, body },
      data: { type: event.event_type, chatId: event.chat_id },
      android: {
        priority: "high",
        notification: { channel_id: "messages", sound: "default" },
      },
    },
  };
}

function genericCopy(language: string): {
  newMessage: string;
  inviteClaimed: string;
} {
  return {
    de: {
      newMessage: "Du hast eine neue Nachricht",
      inviteClaimed: "Dein Freund ist dem Chat beigetreten",
    },
    es: {
      newMessage: "Tienes un mensaje nuevo",
      inviteClaimed: "Tu amigo se ha unido al chat",
    },
    uk: {
      newMessage: "У вас нове повідомлення",
      inviteClaimed: "Ваш друг приєднався до чату",
    },
  }[language] ?? {
    newMessage: "You have a new message",
    inviteClaimed: "Your friend joined the chat",
  };
}

export function fcmErrorCode(value: unknown): string {
  if (typeof value !== "object" || value === null) return "unknown";
  const error = (value as Record<string, unknown>).error;
  if (typeof error !== "object" || error === null) return "unknown";
  const errorRecord = error as Record<string, unknown>;
  const details = errorRecord.details;
  if (Array.isArray(details)) {
    for (const detail of details) {
      if (typeof detail !== "object" || detail === null) continue;
      const code = (detail as Record<string, unknown>).errorCode;
      if (typeof code === "string") return code;
    }
  }
  return typeof errorRecord.status === "string" ? errorRecord.status : "unknown";
}

export function isStaleFcmToken(code: string): boolean {
  return code === "UNREGISTERED";
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}
