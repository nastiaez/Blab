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
    throw new Error("legacy_destructive_task_requires_reconciliation");
  }
  const user = await findStreamAccount(server, userId);
  if (user == null) return { done: true, taskId: null };
  // Stream ListDevices returns 404 for inactive users. QueryUsers with
  // include_deactivated_users returns their authoritative devices instead.
  // Never reactivate merely to enumerate devices, or treat arbitrary 404 as empty.
  const deviceList = user.deactivated_at != null
    ? { devices: user.devices }
    : await server.request("devices", undefined, {
      query: { user_id: userId },
    });
  if (!Array.isArray(deviceList.devices) || deviceList.devices.length > 100) {
    throw new Error("invalid_device_response");
  }
  await Promise.all(deviceList.devices.map(async (device: { id?: unknown }) => {
    if (typeof device.id !== "string" || device.id.length === 0) {
      throw new Error("invalid_device_identity");
    }
    await server.request("devices", undefined, {
      method: "DELETE",
      query: { id: device.id, user_id: userId },
    });
  }));
  // Upsert merges custom fields. Explicitly unset every provider-returned
  // custom field instead, retaining only provider-owned operational metadata.
  const providerFields = new Set([
    "id",
    "role",
    "created_at",
    "updated_at",
    "last_active",
    "online",
    "banned",
    "ban_expires",
    "deactivated_at",
    "revoke_tokens_issued_before",
    "teams",
    "devices",
    "invisible",
    "language",
    "unread_count",
    "total_unread_count",
    "unread_channels",
    "unread_threads",
    "shadow_banned",
    "blocked_user_ids",
    "mutes",
    "channel_mutes",
  ]);
  const unset = Object.keys(user).filter((key) =>
    !providerFields.has(key) && key !== "name" && key !== "image"
  );
  // Neither ListDevices nor partial user updates accept inactive users.
  // A completed retry must verify the minimized snapshot; legacy unsanitized
  // inactive identities require reconciliation, never automatic reactivation.
  if (user.deactivated_at != null) {
    if (
      deviceList.devices.length || unset.length ||
      user.name !== "Deleted account" || user.image !== "" ||
      user.language !== "en" || !Array.isArray(user.teams) || user.teams.length
    ) {
      throw new Error("inactive_identity_requires_reconciliation");
    }
    return { done: true, taskId: null };
  }
  await server.request("users", {
    users: [{
      id: userId,
      set: {
        name: "Deleted account",
        image: "",
        language: "en",
        teams: [],
        revoke_tokens_issued_before: new Date().toISOString(),
      },
      unset,
    }],
  }, { method: "PATCH" });
  await deactivateStreamAccount(server, userId);
  return { done: true, taskId: null };
}
