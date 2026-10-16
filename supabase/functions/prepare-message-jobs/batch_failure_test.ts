import { batchFailureReason } from "./batch_failure.ts";
Deno.test("batch failures retain the rejecting stage without private database detail", () => {
  for (const stage of ["stale_batch", "stale_readable", "stale_completion"]) {
    if (
      batchFailureReason({ message: stage, details: "private" }) !==
        `batch_commit_${stage}`
    ) throw Error(stage);
  }
});
Deno.test("constraint failures retain SQLSTATE but never the row body", () => {
  if (
    batchFailureReason({
      code: "23514",
      message: "private row text",
      details: "private",
    }) !== "batch_commit_sql_23514"
  ) throw Error("SQLSTATE lost");
  for (
    const e of [null, "private", { message: "private" }, {
      code: "private data",
    }]
  ) {
    if (batchFailureReason(e) !== "batch_commit_failed") {
      throw Error("private detail leaked");
    }
  }
});
