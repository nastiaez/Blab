import { handle } from "./index.ts";
function assert(x: unknown) {
  if (!x) throw new Error("assertion failed");
}
Deno.test("method guard and preflight require no provider", async () => {
  assert(
    (await handle(new Request("http://localhost", { method: "GET" })))
      .status === 405,
  );
  assert(
    (await handle(new Request("http://localhost", { method: "OPTIONS" })))
      .status === 204,
  );
});
Deno.test("hosted environment refuses endpoint", async () => {
  const old = Deno.env.get("BLAB_ENV");
  try {
    Deno.env.set("BLAB_ENV", "production");
    const response = await handle(
      new Request("http://localhost", { method: "POST" }),
    );
    assert(response.status === 503);
    assert((await response.json()).error === "local_only");
  } finally {
    if (old === undefined) Deno.env.delete("BLAB_ENV");
    else Deno.env.set("BLAB_ENV", old);
  }
});
Deno.test("local missing auth and disabled aids never reach database", async () => {
  const old = Deno.env.get("BLAB_ENV");
  try {
    Deno.env.set("BLAB_ENV", "local");
    assert(
      (await handle(new Request("http://localhost", { method: "POST" })))
        .status === 401,
    );
    const response = await handle(
      new Request("http://localhost", {
        method: "POST",
        headers: { Authorization: "Bearer fake" },
        body: JSON.stringify({
          messageId: "11111111-1111-4111-8111-111111111111",
          kind: "vocabulary",
          text: "word",
          start: 0,
          end: 4,
          targetLang: "es",
          knownLang: "fr",
          aidsEnabled: false,
        }),
      }),
    );
    assert(response.status === 403);
    assert((await response.json()).error === "learning_aids_off");
  } finally {
    if (old === undefined) Deno.env.delete("BLAB_ENV");
    else Deno.env.set("BLAB_ENV", old);
  }
});
