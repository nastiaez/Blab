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
}: {
  status: number;
  attempts: number;
}): JobOutcome {
  if (status >= 200 && status < 300) return { kind: "ready" };
  if (status === 409) return { kind: "stale" };
  const retryable = status === 408 || status === 425 || status === 429 ||
    status >= 500;
  if (retryable && attempts < MAX_JOB_ATTEMPTS) {
    return {
      kind: "retry",
      delaySeconds: Math.min(300, 5 * 2 ** attempts),
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
  const outcomes: Array<{ job: T; result?: R; error?: string }> = [];
  for (const job of jobs) {
    try {
      outcomes.push({ job, result: await run(job) });
    } catch (error) {
      outcomes.push({
        job,
        error: error instanceof Error ? error.message : "unknown",
      });
    }
  }
  return outcomes;
}
