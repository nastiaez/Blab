import { reconcileDeletedSend } from "./deleted_account_send.ts";
const fence = {
  message_id: "m",
  chat_id: "c",
  actor_id: "a",
  blocked_at: "2026-10-29T12:00:00Z",
};
function assert(value: unknown) {
  if (!value) throw new Error("assertion_failed");
}
for (
  const created of [
    "2026-10-29T11:59:59Z",
    "2026-10-29T12:00:00Z",
    "2026-10-29T12:00:01Z",
  ]
) {
  Deno.test(
    "BLA-31 in-flight canonical acceptance boundary: " + created,
    async () => {
      const calls: string[] = [];
      const result = await reconcileDeletedSend({
        request: async (path, _body, options) => {
          calls.push(options?.method ?? "GET");
          return {
            message: {
              id: "m",
              cid: "blab:c",
              user: { id: "a" },
              created_at: created,
            },
          };
        },
      }, fence);
      const late = Date.parse(created) > Date.parse(fence.blocked_at);
      assert(result.state === (late ? "removed" : "retained"));
      assert(calls.includes("DELETE") === late);
    },
  );
}
Deno.test("BLA-31 durable retry distinguishes absence from provider outage", async () => {
  const absent = await reconcileDeletedSend({
    request: async () => {
      throw new Error("stream_http_404");
    },
  }, fence);
  assert(absent.state === "absent");
  let failed = false;
  try {
    await reconcileDeletedSend({
      request: async () => {
        throw new Error("timeout");
      },
    }, fence);
  } catch {
    failed = true;
  }
  assert(failed);
});
for (
  const bad of [{
    id: "other",
    cid: "blab:c",
    user: { id: "a" },
    created_at: "2026-10-29T12:01:00Z",
  }, {
    id: "m",
    cid: "blab:other",
    user: { id: "a" },
    created_at: "2026-10-29T12:01:00Z",
  }, {
    id: "m",
    cid: "blab:c",
    user: { id: "other" },
    created_at: "2026-10-29T12:01:00Z",
  }, { id: "m", cid: "blab:c", user: { id: "a" }, created_at: "invalid" }]
) {
  Deno.test(
    "BLA-31 compensation fails closed for " + JSON.stringify(bad),
    async () => {
      let deleted = false, failed = false;
      try {
        await reconcileDeletedSend({
          request: async (_path, _body, options) => {
            deleted ||= options?.method === "DELETE";
            return { message: bad };
          },
        }, fence);
      } catch {
        failed = true;
      }
      assert(failed && !deleted);
    },
  );
}
Deno.test("BLA-31 failed compensation remains retryable", async () => {
  let failed = false;
  try {
    await reconcileDeletedSend({
      request: async (_path, _body, options) => {
        if (options?.method === "DELETE") throw new Error("timeout");
        return {
          message: {
            id: "m",
            cid: "blab:c",
            user: { id: "a" },
            created_at: "2026-10-29T12:01:00Z",
          },
        };
      },
    }, fence);
  } catch {
    failed = true;
  }
  assert(failed);
});
