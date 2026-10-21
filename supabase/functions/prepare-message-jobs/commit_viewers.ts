import { batchFailureReason } from "./batch_failure.ts";
type Rpc = (
  name: string,
  args: Record<string, unknown>,
) => PromiseLike<{ data: unknown; error: unknown }>;

export async function commitGroupViewers(
  rpc: Rpc,
  entries: Array<{ jobId: string; lease: string; result: unknown }>,
) {
  const reply = await rpc("complete_group_translation_viewers", {
    p_entries: entries,
  });
  if (
    reply.error || !Array.isArray(reply.data) ||
    reply.data.length !== entries.length
  ) throw new Error("batch_commit_failed");
  const rows = reply.data as Array<{ jobId: string; error: string | null }>;
  if (
    rows.some((r, i) =>
      r.jobId !== entries[i].jobId ||
      (r.error !== null && typeof r.error !== "string")
    )
  ) throw new Error("batch_commit_failed");
  return rows;
}
// One transaction per viewer; generating the shared response still costs one call.
export async function commitViewers(
  rpc: Rpc,
  entries: Array<{ jobId: string; lease: string; result: unknown }>,
) {
  const outcomes: Array<{ jobId: string; error: string | null }> = [];
  for (const entry of entries) {
    if (!entry.result) {
      outcomes.push({ jobId: entry.jobId, error: "invalid_viewer_result" });
      continue;
    }
    try {
      const reply = await rpc("complete_translation_message_batch", {
        p_results: [entry],
      });
      outcomes.push({
        jobId: entry.jobId,
        error: reply.error || reply.data !== true
          ? batchFailureReason(reply.error)
          : null,
      });
    } catch {
      outcomes.push({
        jobId: entry.jobId,
        error: "batch_commit_transport_failed",
      });
    }
  }
  return outcomes;
}
