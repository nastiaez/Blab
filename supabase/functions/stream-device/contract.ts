export function streamDeviceInput(input: unknown): {
  token: string;
  action: "register" | "unregister";
  previewsEnabled: boolean;
} {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new Error("invalid_device");
  }
  const value = input as Record<string, unknown>;
  if (
    typeof value.token !== "string" || value.token.length < 20 ||
    value.token.length > 4096 || /\s/.test(value.token) ||
    !["register", "unregister"].includes(String(value.action)) ||
    (value.previewsEnabled !== undefined &&
      typeof value.previewsEnabled !== "boolean")
  ) {
    throw new Error("invalid_device");
  }
  return {
    token: value.token,
    action: value.action as "register" | "unregister",
    previewsEnabled: value.previewsEnabled !== false,
  };
}
export function streamPushProvider(previews: boolean): string {
  return previews ? "blab-android" : "blab-android-private";
}
