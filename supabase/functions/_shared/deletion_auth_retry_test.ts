Deno.test("BLA31 Auth transaction retry is bounded and does not replay provider erasure", async () => {
  const s = await Deno.readTextFile(
    new URL("../delete-account/index.ts", import.meta.url),
  );
  const start = s.search(/for\s*\(\s*let attempt = 0;/);
  if (start < 0) throw new Error("retry_loop_missing");
  const end = s.indexOf("if (delErr)", start);
  const loop = s.slice(start, end);
  for (
    const required of [
      "attempt < 2",
      "delErr?.status === 500",
      'delErr.message === "Database error deleting user"',
      "setTimeout",
      "admin.auth.admin.deleteUser(userId)",
    ]
  ) if (!loop.includes(required)) throw new Error(required);
  if (
    loop.includes("deactivateStreamAccount") ||
    loop.includes("advanceStreamErasure") ||
    loop.includes("queue_account_private_media_cleanup")
  ) throw new Error("side_effects_replayed");
});
