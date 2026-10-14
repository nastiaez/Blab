import { BodyTooLarge, readBoundedBody } from "../_shared/bounded_body.ts";

export class UnsupportedWebhookEncoding extends Error {}

// Stream signs the exact uncompressed bytes, including when middleware has
// already decoded the envelope. See getstream.io/docs/platform/webhooks/.
export async function decodeStreamWebhookBody(
  raw: Uint8Array,
  encoding: string | null,
  limit = 262144,
): Promise<Uint8Array> {
  if (encoding && !["identity", "gzip"].includes(encoding.toLowerCase())) {
    throw new UnsupportedWebhookEncoding();
  }
  const compressed = raw[0] === 0x1f && raw[1] === 0x8b;
  if (raw.length > limit) throw new BodyTooLarge();
  if (!compressed) return raw;
  const stream = new ReadableStream<BufferSource>({
    start(controller) {
      controller.enqueue(new Uint8Array(raw));
      controller.close();
    },
  }).pipeThrough(new DecompressionStream("gzip"));
  return await readBoundedBody(
    new Request("https://webhook-body.invalid", {
      method: "POST",
      body: stream,
    }),
    limit,
  );
}
