Deno.test("BLA-31 partial provider configuration fails before erasure side effects", async () => {
  const source = await Deno.readTextFile(new URL("../delete-account/index.ts", import.meta.url));
  const guard = source.indexOf("if (Boolean(key) !== Boolean(secret))");
  if (guard < 0 || guard > source.indexOf("queue_stream_account_erasure") || guard > source.indexOf("queue_account_private_media_cleanup")) throw new Error("partial_config_not_fenced");
  const branch = source.slice(guard, source.indexOf("let vendor", guard));
  if (!branch.includes("503")) throw new Error("partial_config_not_retryable");
});
