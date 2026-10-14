import { StreamServer } from "./stream_server.ts";

type Server = Pick<StreamServer, "request">;
export async function findStreamAccount(server: Server, userId: string) {
  const response = await server.request("users", undefined, {
    query: {
      payload: JSON.stringify({
        filter_conditions: { id: { $eq: userId } },
        limit: 1,
        include_deactivated_users: true,
      }),
    },
  });
  if (!Array.isArray(response.users)) throw new Error("invalid_user_response");
  const user = response.users[0];
  if (user != null && user.id !== userId) throw new Error("identity_mismatch");
  return user as Record<string, unknown> | undefined;
}

export async function deactivateStreamAccount(server: Server, userId: string) {
  const user = await findStreamAccount(server, userId);
  if (user == null || user.deactivated_at != null) return false;
  await server.request(`users/${userId}/deactivate`, {
    mark_messages_deleted: false,
  });
  return true;
}

export async function advanceStreamErasure(
  server: Server,
  userId: string,
  taskId: string | null,
) {
  if (taskId != null) {
    const task = await server.request(`tasks/${taskId}`);
    if (task.task_id !== taskId) throw new Error("task_identity_mismatch");
    if (task.status === "failed" || task.error != null) {
      throw new Error("erasure_task_failed");
    }
    return { done: task.status === "completed", taskId };
  }
  if (await findStreamAccount(server, userId) == null) {
    return { done: true, taskId: null };
  }
  const task = await server.request("users/delete", {
    user_ids: [userId],
    user: "hard",
    messages: "hard",
    conversations: "hard",
    files: true,
  });
  if (
    typeof task.task_id !== "string" ||
    !/^[A-Za-z0-9_-]{1,200}$/.test(task.task_id)
  ) {
    throw new Error("invalid_erasure_task");
  }
  return { done: false, taskId: task.task_id };
}
