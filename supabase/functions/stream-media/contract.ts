export const imageByteLimit = 10 * 1024 * 1024;
export function detectedImageMime(bytes: Uint8Array): string | null {
  const matches = (offset: number, expected: number[]) =>
    expected.every((value, index) => bytes[offset + index] === value);
  if (matches(0, [0xff, 0xd8, 0xff])) return "image/jpeg";
  if (matches(0, [137, 80, 78, 71, 13, 10, 26, 10])) return "image/png";
  if (
    matches(0, [71, 73, 70, 56]) && (bytes[4] === 55 || bytes[4] === 57) &&
    bytes[5] === 97
  ) return "image/gif";
  if (matches(0, [82, 73, 70, 70]) && matches(8, [87, 69, 66, 80])) {
    return "image/webp";
  }
  return null;
}
export async function imageHash(bytes: Uint8Array): Promise<string> {
  return [
    ...new Uint8Array(
      await crypto.subtle.digest("SHA-256", new Uint8Array(bytes)),
    ),
  ].map(
    (value) => value.toString(16).padStart(2, "0"),
  ).join("");
}
