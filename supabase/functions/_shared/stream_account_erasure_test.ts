import {
  advanceStreamErasure,
  deactivateStreamAccount,
} from "./stream_account_erasure.ts";
import { StreamServer } from "./stream_server.ts";
function fixture(
  handler: (path: string, body: unknown, options: unknown) => unknown,
) {
  return {
    request: async (path: string, body?: unknown, options?: unknown) =>
      handler(path, body, options),
  } as Pick<StreamServer, "request">;
}
function assert(value: unknown) {
  if (!value) throw new Error("assertion_failed");
}
async function rejects(work: Promise<unknown>) {
  let rejected = false;
  try {
    await work;
  } catch {
    rejected = true;
  }
  assert(rejected);
}
Deno.test("deletion query includes deactivated identities and revokes access before hard purge", async () => {
  const calls: string[] = [];
  const server = fixture((path, body, options) => {
    calls.push(path);
    if (path === "users") {
      const payload = JSON.parse(
        (options as { query: { payload: string } }).query.payload,
      );
      assert(
        payload.include_deactivated_users === true &&
          payload.filter_conditions.id.$eq === "actor",
      );
      return { users: [{ id: "actor" }] };
    }
    assert(
      path === "users/actor/deactivate" &&
        (body as Record<string, unknown>).mark_messages_deleted === false,
    );
    return {};
  });
  assert(await deactivateStreamAccount(server, "actor") === true);
  assert(calls.length === 2);
});
Deno.test("already deactivated account is not silently mistaken for hard-erased account", async () => {
  const server = fixture((path, body) => {
    if (path === "users") {
      return { users: [{ id: "actor", deactivated_at: "2026-10-14" }] };
    }
    assert(path === "users/delete");
    const request = body as Record<string, unknown>;
    assert(JSON.stringify(request.user_ids) === '["actor"]');
    assert(
      request.user === "hard" && request.messages === "hard" &&
        request.conversations === "hard" && request.files === true,
    );
    return { task_id: "owned-task" };
  });
  const result = await advanceStreamErasure(server, "actor", null);
  assert(!result.done && result.taskId === "owned-task");
});
Deno.test("absent vendor identity settles without creating another destructive task", async () => {
  let calls = 0;
  const result = await advanceStreamErasure(
    fixture((path) => {
      calls++;
      assert(path === "users");
      return { users: [] };
    }),
    "actor",
    null,
  );
  assert(result.done && result.taskId === null && calls === 1);
});
Deno.test("pending task is resumed by identity rather than duplicated", async () => {
  const result = await advanceStreamErasure(
    fixture((path) => {
      assert(path === "tasks/owned-task");
      return { task_id: "owned-task", status: "running" };
    }),
    "actor",
    "owned-task",
  );
  assert(!result.done && result.taskId === "owned-task");
});
Deno.test("only confirmed task completion settles erasure", async () => {
  const result = await advanceStreamErasure(
    fixture(() => ({ task_id: "owned-task", status: "completed" })),
    "actor",
    "owned-task",
  );
  assert(result.done);
  await rejects(
    advanceStreamErasure(
      fixture(() => ({ task_id: "other-task", status: "completed" })),
      "actor",
      "owned-task",
    ),
  );
});
Deno.test("failed or malformed tasks never claim a successful account purge", async () => {
  await rejects(
    advanceStreamErasure(
      fixture(() => ({ task_id: "owned-task", status: "failed" })),
      "actor",
      "owned-task",
    ),
  );
  await rejects(
    advanceStreamErasure(
      fixture((path) =>
        path === "users"
          ? { users: [{ id: "actor" }] }
          : { task_id: "private url / invalid" }
      ),
      "actor",
      null,
    ),
  );
  await rejects(
    deactivateStreamAccount(
      fixture(() => ({ users: [{ id: "different" }] })),
      "actor",
    ),
  );
});
