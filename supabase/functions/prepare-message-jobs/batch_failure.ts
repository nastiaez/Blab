// Keep diagnostic codes, never raw database details (which can contain messages).
export function batchFailureReason(error: unknown): string {
  const e = error && typeof error === "object"
    ? error as Record<string, unknown>
    : {};
  if (
    typeof e.message === "string" &&
    [
      "stale_batch",
      "mixed_batch",
      "stale_readable",
      "stale_completion",
      "invalid_batch",
    ].includes(e.message)
  ) {
    return `batch_commit_${e.message}`;
  }
  return typeof e.code === "string" && /^[0-9A-Z]{5}$/.test(e.code)
    ? `batch_commit_sql_${e.code}`
    : "batch_commit_failed";
}
