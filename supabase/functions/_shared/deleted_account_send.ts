import type { StreamServer } from "./stream_server.ts";
type Server = Pick<StreamServer, "request">;
export type DeletedSendFence = {
  message_id: string;
  chat_id: string;
  actor_id: string;
  blocked_at: string;
};
export async function reconcileDeletedSend(
  server: Server,
  fence: DeletedSendFence,
) {
  let message: Record<string, unknown>;
  try {
    message = (await server.request("messages/" + fence.message_id, undefined, {
      query: { show_deleted_message: "true" },
    })).message as Record<string, unknown>;
  } catch (error) {
    if (error instanceof Error && error.message === "stream_http_404") {
      return { state: "absent" as const };
    }
    throw error;
  }
  if (
    !message || message.id !== fence.message_id ||
    message.cid !== "blab:" + fence.chat_id ||
    (message.user as { id?: string })?.id !== fence.actor_id
  ) throw new Error("identity_mismatch");
  const created = Date.parse(String(message.created_at));
  const blocked = Date.parse(fence.blocked_at);
  if (!Number.isFinite(created) || !Number.isFinite(blocked)) {
    throw new Error("invalid_timestamp");
  }
  // Lost acknowledgments accepted before deletion are retained history too.
  if (created <= blocked) return { state: "retained" as const, message };
  await server.request("messages/" + fence.message_id, undefined, {
    method: "DELETE",
    query: { hard: "true" },
  });
  return { state: "removed" as const };
}
