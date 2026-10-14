export const MAX_JOB_ATTEMPTS = 4;

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export type PreparationJob = {
  id: string;
  created_at: string;
  attempts: number;
};

export type JobOutcome =
  | { kind: "ready" }
  | { kind: "stale" }
  | { kind: "retry"; delaySeconds: number }
  | { kind: "failed" };

export function workerJobId(value: unknown): string | null {
  if (typeof value !== "object" || value === null) return null;
  const id = (value as { jobId?: unknown }).jobId;
  return typeof id === "string" && UUID_PATTERN.test(id) ? id : null;
}

export function workerBatchLimit(value: unknown): number {
  if (typeof value !== "object" || value === null) return 10;
  const raw = (value as { limit?: unknown }).limit;
  return typeof raw === "number" && Number.isFinite(raw)
    ? Math.max(1, Math.min(20, Math.floor(raw)))
    : 10;
}

export function orderedJobs<T extends PreparationJob>(jobs: T[]): T[] {
  return [...jobs].sort((left, right) =>
    left.created_at.localeCompare(right.created_at) ||
    left.id.localeCompare(right.id)
  );
}

export function planJobOutcome({
  status,
  attempts,
  retryAfterSeconds = 0,
  jitter = 0,
}: {
  status: number;
  attempts: number;
  retryAfterSeconds?: number;
  jitter?: number;
}): JobOutcome {
  if (status >= 200 && status < 300) return { kind: "ready" };
  if (status === 409) return { kind: "stale" };
  const retryable = status === 408 || status === 425 || status === 429 ||
    status >= 500;
  if (retryable && attempts < MAX_JOB_ATTEMPTS) {
    return {
      kind: "retry",
      delaySeconds: Math.max(
        Math.ceil(retryAfterSeconds),
        Math.ceil(
          Math.min(30, 2 ** attempts) * (1 + Math.max(0, Math.min(1, jitter))),
        ),
      ),
    };
  }
  return { kind: "failed" };
}

export async function settleJobs<
  T extends PreparationJob,
  R,
>(
  jobs: T[],
  run: (job: T) => Promise<R>,
): Promise<Array<{ job: T; result?: R; error?: string }>> {
  // Postgres owns the global per-phase capacity. Start only that leased
  // batch together; serial execution would waste reserved sentence slots.
  return await Promise.all(jobs.map(async (job) => {
    try {
      return { job, result: await run(job) };
    } catch (error) {
      return {
        job,
        error: error instanceof Error ? error.message : "unknown",
      };
    }
  }));
}

export function jobFailureReason(body: unknown, status: number): string {
  const fields = body && typeof body === "object"
    ? body as Record<string, unknown>
    : {};
  for (const value of [fields.reason, fields.error]) {
    if (typeof value === "string" && /^[a-zA-Z0-9_]{1,96}$/.test(value)) {
      return value;
    }
  }
  return status >= 200 && status < 300 ? "ready" : `http_${status}`;
}
