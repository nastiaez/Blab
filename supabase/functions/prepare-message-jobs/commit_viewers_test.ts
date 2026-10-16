import { commitViewers } from "./commit_viewers.ts";
Deno.test("one rejected viewer cannot discard another viewer result", async () => {
  const saved: string[] = [];
  const outcomes = await commitViewers(
    async (_, args) => {
      const rows = args.p_results as Array<{ jobId: string }>;
      if (rows.length !== 1) throw Error("coupled transaction");
      if (rows[0].jobId === "bad") {
        return {
          data: null,
          error: { message: "stale_completion" },
        };
      }
      saved.push(rows[0].jobId);
      return { data: true, error: null };
    },
    ["good-before", "bad", "good-after"].map((jobId) => ({
      jobId,
      lease: "lease",
      result: {},
    })),
  );
  if (
    saved.join(",") !== "good-before,good-after" ||
    outcomes.filter((o) => o.error).length !== 1
  ) throw Error("viewer isolation failed");
});
Deno.test("transport failure is bounded to its viewer and does not skip others", async () => {
  let calls = 0;
  const result = await commitViewers(async () => {
    if (++calls === 1) throw Error("private transport details");
    return { data: true, error: null };
  }, ["one", "two"].map((jobId) => ({ jobId, lease: "lease", result: {} })));
  if (
    calls !== 2 || result[0].error !== "batch_commit_transport_failed" ||
    result[1].error !== null
  ) throw Error("transport isolation failed");
});

Deno.test("missing viewer output never reaches the save RPC", async () => {
  let calls = 0;
  const r = await commitViewers(async () => {
    calls++;
    return { data: true, error: null };
  }, [{ jobId: "missing", lease: "lease", result: null }]);
  if (calls !== 0 || r[0].error !== "invalid_viewer_result") {
    throw Error("missing output submitted");
  }
});
