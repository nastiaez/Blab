import {
  advanceStreamErasure,
  deactivateStreamAccount,
} from "./stream_account_erasure.ts";
function assert(v: unknown) {
  if (!v) throw new Error("assertion_failed");
}
Deno.test("BLA-31 retains messages conversations and files while revoking vendor access", async () => {
  const calls: Array<{ path: string; body: unknown }> = [];
  const server = {
    request: async (path: string, body?: unknown) => {
      calls.push({ path, body });
      if (path === "devices") return { devices: [] };
      return path === "users" && body == null
        ? { users: [{ id: "actor" }] }
        : {};
    },
  };
  const result = await advanceStreamErasure(server, "actor", null);
  assert(result.done && result.taskId === null);
  assert(calls.every((c) => c.path !== "users/delete"));
  assert(
    calls.some((c) =>
      c.path === "users/actor/deactivate" &&
      (c.body as Record<string, unknown>).mark_messages_deleted === false
    ),
  );
  const minimized = calls.find((c) => c.path === "users" && c.body != null)!;
  assert(JSON.stringify(minimized.body).includes("Deleted account"));
});
Deno.test("BLA-31 legacy destructive tasks require reconciliation, never retention success", async () => {
  let called = false, rejected = false;
  try {
    await advanceStreamErasure(
      {
        request: async () => {
          called = true;
          return {};
        },
      },
      "actor",
      "legacy",
    );
  } catch {
    rejected = true;
  }
  assert(rejected && !called);
});
Deno.test("BLA-31 absent vendor identity settles idempotently", async () => {
  const result = await advanceStreamErasure(
    { request: async () => ({ users: [] }) },
    "actor",
    null,
  );
  assert(result.done);
});
Deno.test("BLA-31 mismatched identity fails closed", async () => {
  let rejected = false;
  try {
    await deactivateStreamAccount({
      request: async () => ({ users: [{ id: "other" }] }),
    }, "actor");
  } catch {
    rejected = true;
  }
  assert(rejected);
});

Deno.test("BLA-31 provider PATCH unsets unknown private custom fields before deactivation", async () => {
  const calls: Array<{ path: string; body: any; method?: string }> = [];
  await advanceStreamErasure(
    {
      request: async (path, body, options) => {
        calls.push({ path, body, method: options?.method });
        if (path === "devices") return { devices: [] };
        return body == null
          ? {
            users: [{
              id: "actor",
              name: "Real name",
              image: "private-avatar",
              email: "private",
              biography: "private",
              preferences: { secret: true },
              role: "user",
            }],
          }
          : {};
      },
    },
    "actor",
    null,
  );
  const patch = calls.find((c) => c.method === "PATCH")!;
  assert(patch.path === "users");
  const minimized = patch.body.users[0];
  assert(
    minimized.id === "actor" && minimized.set.name === "Deleted account" &&
      minimized.set.image === "",
  );
  assert(
    ["email", "biography", "preferences"].every((key) =>
      minimized.unset.includes(key)
    ),
  );
  assert(
    !minimized.unset.includes("id") &&
      !minimized.unset.includes("deactivated_at"),
  );
  assert(calls.every((c) => !c.path.includes("delete")));
});

Deno.test("BLA-31 removes vendor push devices using only the deleted identity", async () => {
  const calls: Array<{ path: string; options: any }> = [];
  await advanceStreamErasure(
    {
      request: async (path, _body, options) => {
        calls.push({ path, options });
        if (path === "devices" && options?.method !== "DELETE") {
          return {
            devices: [{ id: "private-token" }],
          };
        }
        return { users: [{ id: "actor" }] };
      },
    },
    "actor",
    null,
  );
  const removal = calls.find((c) =>
    c.path === "devices" && c.options?.method === "DELETE"
  );
  assert(
    removal?.options.query.user_id === "actor" &&
      removal.options.query.id === "private-token",
  );
});

Deno.test("BLA31 already-minimized inactive snapshot settles without forbidden APIs", async () => {
  const calls: string[] = [];
  const result = await advanceStreamErasure(
    {
      request: async (path) => {
        calls.push(path);
        if (path !== "users") throw new Error("inactive API forbidden");
        return {
          users: [{
            id: "actor",
            name: "Deleted account",
            image: "",
            language: "en",
            teams: [],
            devices: [],
            deactivated_at: "now",
          }],
        };
      },
    },
    "actor",
    null,
  );
  assert(result.done && calls.length === 1);
});
for (
  const extra of [{ name: "Private" }, { email: "private" }, {
    devices: undefined,
  }]
) {
  Deno.test(
    "BLA31 incomplete inactive snapshot fails closed " + JSON.stringify(extra),
    async () => {
      let rejected = false;
      try {
        await advanceStreamErasure(
          {
            request: async (path, _body, options) => {
              assert(path === "users" && !options?.method);
              return {
                users: [{
                  id: "actor",
                  name: "Deleted account",
                  image: "",
                  language: "en",
                  teams: [],
                  devices: [],
                  deactivated_at: "now",
                  ...extra,
                }],
              };
            },
          },
          "actor",
          null,
        );
      } catch {
        rejected = true;
      }
      assert(rejected);
    },
  );
}
