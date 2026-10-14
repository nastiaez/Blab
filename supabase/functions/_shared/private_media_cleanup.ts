type RemovalError = { statusCode?: string; message?: string };
export function isMissingPrivateObject(error: RemovalError | null) {
  return error != null && ["400", "404"].includes(String(error.statusCode)) &&
    /object not found|does not exist/i.test(error.message ?? "");
}
