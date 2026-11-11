export type LeaseGuardOptions = {
  deadlineMs: number;
  renew: () => Promise<boolean>;
  intervalMs?: number;
  renewalTimeoutMs?: number;
};

/** Token-scoped renewal never extends the fixed generation deadline. */
export async function withLeaseGuard<T>(
  options: LeaseGuardOptions,
  work: (signal: AbortSignal) => Promise<T>,
): Promise<T> {
  if (options.deadlineMs <= performance.now()) {
    throw new Error("generation_budget_exhausted");
  }
  const controller = new AbortController();
  let stopped = false;
  let timer: ReturnType<typeof setTimeout> | undefined;
  let rejectLost!: (reason: Error) => void;
  const lost = new Promise<never>((_, reject) => rejectLost = reject);
  const fail = (reason: string) => {
    if (stopped || controller.signal.aborted) return;
    controller.abort(reason);
    rejectLost(new Error(reason));
  };
  const deadline = setTimeout(
    () => fail("generation_budget_exhausted"),
    Math.max(0, options.deadlineMs - performance.now()),
  );
  const renewOnce = async () => {
    let timeout: ReturnType<typeof setTimeout> | undefined;
    try {
      const ok = await Promise.race([
        options.renew(),
        new Promise<false>((resolve) => {
          timeout = setTimeout(
            () => resolve(false),
            options.renewalTimeoutMs ?? 5_000,
          );
        }),
      ]);
      if (!ok) throw new Error("lease_expired");
      if (controller.signal.aborted) {
        throw new Error(String(controller.signal.reason));
      }
    } finally {
      clearTimeout(timeout);
    }
  };
  let inFlight: Promise<void> | undefined;
  const renew = () => {
    if (!inFlight) {
      inFlight = renewOnce().finally(() => {
        inFlight = undefined;
      });
    }
    return inFlight;
  };
  const tick = async () => {
    try {
      await renew();
      if (!stopped) timer = setTimeout(tick, options.intervalMs ?? 10_000);
    } catch {
      fail("lease_expired");
    }
  };
  try {
    await Promise.race([renew(), lost]);
    if (options.deadlineMs <= performance.now()) {
      throw new Error("generation_budget_exhausted");
    }
    timer = setTimeout(tick, options.intervalMs ?? 10_000);
    const result = await Promise.race([work(controller.signal), lost]);
    await Promise.race([renew(), lost]);
    if (options.deadlineMs <= performance.now()) {
      throw new Error("generation_budget_exhausted");
    }
    return result;
  } finally {
    stopped = true;
    clearTimeout(timer);
    clearTimeout(deadline);
    controller.abort("lease_guard_settled");
  }
}
