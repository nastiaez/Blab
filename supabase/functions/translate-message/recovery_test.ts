import { firstAccepted } from "./recovery.ts";

function assert(value: boolean, message: string) {
  if (!value) throw new Error(message);
}

Deno.test("fast accepted primary avoids fallback entirely", async () => {
  let fallbacks = 0;
  const value = await firstAccepted(
    async () => ({ result: "primary", reason: "ok" }),
    async () => {
      fallbacks++;
      return { result: "fallback", reason: "ok" };
    },
  );
  assert(
    value.result === "primary" && fallbacks === 0,
    "no unnecessary paid duplicate",
  );
});

Deno.test("invalid primary immediately tries one fallback", async () => {
  let fallbacks = 0;
  const value = await firstAccepted(
    async () => ({ result: null, reason: "semantic_rejection" }),
    async () => {
      fallbacks++;
      return { result: "accepted", reason: "ok" };
    },
  );
  assert(
    value.result === "accepted" && fallbacks === 1,
    "quality failure recovered",
  );
});

Deno.test("slow primary is cancelled after accepted hedge", async () => {
  let aborted = false;
  const value = await firstAccepted<string>(
    (signal) =>
      new Promise((resolve) => {
        signal.addEventListener("abort", () => {
          aborted = true;
          resolve({ result: null, reason: "cancelled" });
        });
      }),
    async () => ({ result: "fallback", reason: "ok" }),
    { hedgeMs: 5, budgetMs: 100 },
  );
  assert(value.result === "fallback" && aborted, "winner terminates loser");
});

Deno.test("failed hedge cannot discard a later valid primary", async () => {
  const value = await firstAccepted(
    async () => {
      await new Promise((r) => setTimeout(r, 15));
      return { result: "primary", reason: "ok" };
    },
    async () => ({ result: null, reason: "invalid" }),
    { hedgeMs: 1, budgetMs: 100 },
  );
  assert(
    value.result === "primary",
    "wait for accepted result, not first settled response",
  );
});

Deno.test("both hung providers settle at the shared deadline", async () => {
  const hang = (signal: AbortSignal) =>
    new Promise<{ result: string | null; reason: string }>((resolve) => {
      signal.addEventListener(
        "abort",
        () => resolve({ result: null, reason: "cancelled" }),
      );
    });
  const value = await firstAccepted(hang, hang, { hedgeMs: 2, budgetMs: 15 });
  assert(
    value.result === null && value.reason === "provider_timeout",
    "finite outcome under total outage",
  );
});
