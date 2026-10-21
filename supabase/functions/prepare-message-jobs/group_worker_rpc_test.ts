import { runMessageBatch } from "./single_call_worker.ts";
import { commitGroupViewers } from "./commit_viewers.ts";

Deno.test("100 cached jobs need one preparation roundtrip and no provider credentials", async () => {
  const jobs = Array.from(
    { length: 100 },
    (_, i) => ({
      id: `j${i}`,
      message_id: "m",
      source_version: "s",
      lease_token: `l${i}`,
      attempts: 1,
    }),
  );
  const calls: string[] = [];
  await runMessageBatch({
    rpc: async (name, args) => {
      calls.push(name);
      if (
        name !== "prepare_translation_viewers" ||
        (args.p_leases as unknown[]).length !== 100
      ) throw Error("per-viewer network fanout");
      return {
        data: jobs.map((j) => ({ id: j.id, prepared: { status: "cached" } })),
        error: null,
      };
    },
  }, jobs);
  if (calls.length !== 1) throw Error("cached group started extra work");
});

Deno.test("100 group completions use one roundtrip and preserve isolated failures", async () => {
  const entries = Array.from(
    { length: 100 },
    (_, i) => ({ jobId: `j${i}`, lease: `l${i}`, result: {} }),
  );
  let calls = 0;
  const results = await commitGroupViewers(async (name, args) => {
    calls++;
    if (
      name !== "complete_group_translation_viewers" ||
      (args.p_entries as unknown[]).length !== 100
    ) throw Error("invalid bulk commit");
    return {
      data: entries.map((e, i) => ({
        jobId: e.jobId,
        error: i === 0 ? "batch_commit_stale_batch" : null,
      })),
      error: null,
    };
  }, entries);
  if (calls !== 1 || results.filter((r) => r.error === null).length !== 99) {
    throw Error("batch failure isolation lost");
  }
});
