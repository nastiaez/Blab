import { streamDeviceInput, streamPushProvider } from "./contract.ts";
Deno.test("device identity and provider cannot be chosen by caller fields", () => {
  const input = streamDeviceInput({
    token: "opaque-token-123456789012345",
    action: "register",
    userId: "someone-else",
    push_provider_name: "arbitrary",
  });
  if (
    "userId" in input ||
    streamPushProvider(input.previewsEnabled) !== "blab-android"
  ) throw new Error("caller authority escaped");
  if (
    streamPushProvider(
      streamDeviceInput({ ...input, previewsEnabled: false }).previewsEnabled,
    ) !== "blab-android-private"
  ) throw new Error("preview privacy lost");
});
Deno.test("device commands reject malformed token, action and privacy", () => {
  for (
    const change of [
      { token: "short" },
      { token: "a".repeat(4097) },
      { token: "with space 123456789012345" },
      { action: "other" },
      { previewsEnabled: "false" },
    ]
  ) {
    let rejected = false;
    try {
      streamDeviceInput({
        token: "opaque-token-123456789012345",
        action: "register",
        ...change,
      });
    } catch {
      rejected = true;
    }
    if (!rejected) throw new Error("invalid device input accepted");
  }
});
