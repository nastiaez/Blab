import { detectedImageMime, imageHash } from "./contract.ts";
Deno.test("actual raster signatures bind MIME; active documents and lies are rejected", () => {
  const fixtures: [number[], string][] = [
    [[0xff, 0xd8, 0xff], "image/jpeg"],
    [[137, 80, 78, 71, 13, 10, 26, 10], "image/png"],
    [[71, 73, 70, 56, 57, 97], "image/gif"],
    [[82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80], "image/webp"],
  ];
  for (const [bytes, mime] of fixtures) {
    if (detectedImageMime(new Uint8Array(bytes)) !== mime) {
      throw new Error("valid raster rejected");
    }
  }
  for (const content of ["<svg></svg>", "%PDF-1.7", "not an image", "GIF88a"]) {
    if (detectedImageMime(new TextEncoder().encode(content)) !== null) {
      throw new Error("invalid media accepted");
    }
  }
});
Deno.test("retries bind immutable original pixels, not a caller file name", async () => {
  const a = await imageHash(new Uint8Array([1, 2, 3]));
  if (
    a !== await imageHash(new Uint8Array([1, 2, 3])) ||
    a === await imageHash(new Uint8Array([1, 2, 4]))
  ) throw new Error("media idempotency hash invalid");
});
