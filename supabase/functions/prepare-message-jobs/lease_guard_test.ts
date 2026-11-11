import { withLeaseGuard } from "./lease_guard.ts";
const delay = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));
function assert(ok: unknown) {
  if (!ok) throw Error("assertion_failed");
}
Deno.test("heartbeat retains ownership through a long request and stops on success", async () => {
  let renewals = 0;
  const value = await withLeaseGuard({
    deadlineMs: performance.now() + 500,
    intervalMs: 5,
    renew: async () => {
      renewals++;
      return true;
    },
  }, async () => {
    await delay(35);
    return "full";
  });
  assert(value === "full" && renewals >= 3);
  const before = renewals;
  await delay(20);
  assert(renewals === before);
});
Deno.test("lost token aborts provider and discards uncancellable late output", async () => {
  let n = 0;
  let signal: AbortSignal | undefined;
  try {
    await withLeaseGuard({
      deadlineMs: performance.now() + 500,
      intervalMs: 5,
      renew: async () => ++n < 2,
    }, async (s) => {
      signal = s;
      await delay(35);
      return "late";
    });
    throw Error("accepted_late");
  } catch (e) {
    assert((e as Error).message === "lease_expired");
  }
  assert(signal?.aborted);
  await delay(40);
});
Deno.test("absolute budget aborts despite healthy heartbeats", async () => {
  let signal: AbortSignal | undefined;
  try {
    await withLeaseGuard({
      deadlineMs: performance.now() + 20,
      intervalMs: 5,
      renew: async () => true,
    }, async (s) => {
      signal = s;
      await delay(40);
      return "late";
    });
    throw Error("unbounded");
  } catch (e) {
    assert((e as Error).message === "generation_budget_exhausted");
  }
  assert(signal?.aborted);
  await delay(45);
});
Deno.test("stalled renewal is bounded and prevents starting paid work", async () => {
  let started = false;
  try {
    await withLeaseGuard({
      deadlineMs: performance.now() + 200,
      renewalTimeoutMs: 10,
      renew: () => new Promise(() => {}),
    }, async () => {
      started = true;
    });
    throw Error("unbounded");
  } catch (e) {
    assert((e as Error).message === "lease_expired");
  }
  assert(!started);
});
Deno.test("final ownership check rejects result even before next periodic heartbeat", async () => {
  let n = 0;
  try {
    await withLeaseGuard({
      deadlineMs: performance.now() + 200,
      renew: async () => ++n === 1,
    }, async () => "answer");
    throw Error("accepted_stale");
  } catch (e) {
    assert((e as Error).message === "lease_expired");
  }
});
Deno.test("failed attempt does not leak timers or prevent independent retry", async () => {
  try {
    await withLeaseGuard({
      deadlineMs: performance.now() + 200,
      renew: async () => true,
    }, async () => {
      throw Error("provider_timeout");
    });
  } catch (e) {
    assert((e as Error).message === "provider_timeout");
  }
  assert(
    await withLeaseGuard({
      deadlineMs: performance.now() + 200,
      renew: async () => true,
    }, async () => 42) === 42,
  );
});

Deno.test("already expired budget starts neither renewal nor work", async () => {
  let calls = 0;
  try {
    await withLeaseGuard({
      deadlineMs: performance.now() - 1,
      renew: async () => {
        calls++;
        return true;
      },
    }, async () => {
      calls++;
    });
    throw Error("expired_started");
  } catch (e) {
    assert((e as Error).message === "generation_budget_exhausted");
  }
  assert(calls === 0);
});
Deno.test("periodic and final renewals never overlap", async () => {
  let active = 0;
  let max = 0;
  const renew = async () => {
    active++;
    max = Math.max(max, active);
    await delay(8);
    active--;
    return true;
  };
  await withLeaseGuard({
    deadlineMs: performance.now() + 500,
    intervalMs: 1,
    renew,
  }, async () => {
    await delay(13);
    return "accepted";
  });
  assert(max === 1);
  await delay(20);
});
