import { batchFailureReason } from "./batch_failure.ts";
type Rpc = (
  name: string,
  args: Record<string, unknown>,
) => PromiseLike<{ data: unknown; error: unknown }>;
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
