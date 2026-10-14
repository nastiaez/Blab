import {
  jobFailureReason,
  orderedJobs,
  planJobOutcome,
  settleJobs,
  workerBatchLimit,
  workerJobId,
} from "./contract.ts";

function assert(condition: boolean, message: string): void {
  if (!condition) throw new Error(message);
}

const jobs = [
  { id: "b", created_at: "2026-08-29T10:00:01Z", attempts: 1 },
  { id: "a", created_at: "2026-08-29T10:00:00Z", attempts: 1 },
  { id: "c", created_at: "2026-08-29T10:00:01Z", attempts: 1 },
];

Deno.test("claims are processed oldest first with a stable tie break", () => {
  assert(
    orderedJobs(jobs).map((job) => job.id).join(",") === "a,b,c",
    "oldest job must be first",
  );
});

Deno.test("one failed job does not stop independent completions", async () => {
  const outcomes = await settleJobs(orderedJobs(jobs), async (job) => {
    if (job.id === "b") throw new Error("provider_unreachable");
    return { status: 200 };
  });
  assert(outcomes.length === 3, "every claimed job must settle");
  assert(outcomes[0].result?.status === 200, "first job completes");
  assert(outcomes[1].error === "provider_unreachable", "failure is retained");
  assert(outcomes[2].result?.status === 200, "later job still completes");
});

Deno.test("transient failures retry with bounded delay", () => {
  const outcome = planJobOutcome({ status: 502, attempts: 2 });
  assert(outcome.kind === "retry", "provider outage retries");
  if (outcome.kind !== "retry") throw new Error("retry outcome required");
  assert(outcome.delaySeconds === 4, "second retry uses bounded backoff");
});

Deno.test("permanent failures stop immediately", () => {
  const outcome = planJobOutcome({ status: 403, attempts: 1 });
  assert(outcome.kind === "failed", "forbidden work is terminal");
});

Deno.test("stale revisions are discarded without retry", () => {
  const outcome = planJobOutcome({ status: 409, attempts: 1 });
  assert(outcome.kind === "stale", "stale variant is discarded");
});

Deno.test("retry budget ends in a terminal failure", () => {
  const outcome = planJobOutcome({ status: 503, attempts: 4 });
  assert(outcome.kind === "failed", "fourth failed attempt is terminal");
});

Deno.test("worker input accepts only bounded batches and job UUIDs", () => {
  assert(workerBatchLimit({ limit: 99 }) === 20, "batch is bounded");
  assert(workerBatchLimit({ limit: 0 }) === 1, "batch has a minimum");
  assert(
    workerJobId({ jobId: "5b000000-0000-4000-8000-000000000001" }) !== null,
    "job UUID passes",
  );
  assert(workerJobId({ jobId: "bad" }) === null, "invalid job ID fails");
});

Deno.test("an unrelated slow job does not delay an already claimed message", async () => {
  let release!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  const started: string[] = [];
  const work = settleJobs(orderedJobs(jobs), async (job) => {
    started.push(job.id);
    if (job.id === "a") await gate;
    return job.id;
  });
  await Promise.resolve();
  release();
  const concurrent = started.length;
  const outcomes = await work;
  assert(
    concurrent === 3,
    "all bounded claims must start without waiting for first result",
  );
  assert(
    outcomes.map((x) => x.result).join(",") === "a,b,c",
    "result order stays deterministic",
  );
});

Deno.test("failure diagnostics retain bounded reasons, never private provider text", () => {
  assert(
    jobFailureReason({
      error: "translation_unavailable",
      reason: "openrouter_source_evidence_conflict",
    }, 502) === "openrouter_source_evidence_conflict",
    "specific reason survives",
  );
  assert(
    jobFailureReason({ reason: "private user text goes here" }, 502) ===
      "http_502",
    "arbitrary provider prose excluded",
  );
});

Deno.test("retry delay respects provider Retry-After", () => {
  const value = planJobOutcome({
    status: 429,
    attempts: 1,
    retryAfterSeconds: 90,
  });
  assert(
    value.kind === "retry" && value.delaySeconds >= 90,
    "no early quota retry",
  );
});
