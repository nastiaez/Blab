export type Candidate<T> = { result: T | null; reason: string };

// Race accepted, fully checked candidates, never raw provider completions.
// Exactly one hedge; one deadline; losers cannot publish database writes.
export function firstAccepted<T>(
  primary: (signal: AbortSignal) => Promise<Candidate<T>>,
  fallback: (signal: AbortSignal) => Promise<Candidate<T>>,
  { hedgeMs = 2500, budgetMs = 8000 } = {},
): Promise<Candidate<T>> {
  return new Promise((resolve) => {
    const controllers = [new AbortController(), new AbortController()];
    let settled = false;
    let fallbackStarted = false;
    let completed = 0;
    let lastReason = "provider_timeout";
    const finish = (value: Candidate<T>) => {
      if (settled) return;
      settled = true;
      clearTimeout(hedge);
      clearTimeout(deadline);
      controllers.forEach((c) => c.abort());
      resolve(value);
    };
    const run = async (candidate: typeof primary, index: number) => {
      let value: Candidate<T>;
      try {
        value = await candidate(controllers[index].signal);
      } catch {
        value = { result: null, reason: "provider_unreachable" };
      }
      if (settled) return;
      completed++;
      if (value.result !== null) {
        finish(value);
        return;
      }
      lastReason = value.reason;
      if (index === 0) startFallback();
      if (completed === 2) finish({ result: null, reason: lastReason });
    };
    const startFallback = () => {
      if (settled || fallbackStarted) return;
      fallbackStarted = true;
      void run(fallback, 1);
    };
    const hedge = setTimeout(startFallback, hedgeMs);
    const deadline = setTimeout(
      () => finish({ result: null, reason: "provider_timeout" }),
      budgetMs,
    );
    void run(primary, 0);
  });
}
