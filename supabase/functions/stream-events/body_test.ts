import { BodyTooLarge } from "../_shared/bounded_body.ts";
import { decodeStreamWebhookBody, UnsupportedWebhookEncoding } from "./body.ts";
import { verifyStreamSignature } from "./contract.ts";

async function gzip(bytes: Uint8Array): Promise<Uint8Array> {
  const stream = new ReadableStream<BufferSource>({
    start(controller) {
      controller.enqueue(new Uint8Array(bytes));
      controller.close();
    },
  }).pipeThrough(new CompressionStream("gzip"));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}
const raw = new TextEncoder().encode(
  '{ "type": "message.new", "text":"Привіт" }',
);
Deno.test("compressed webhook preserves signed Unicode bytes and formatting", async () => {
  const compressed = await gzip(raw);
  const decoded = await decodeStreamWebhookBody(compressed, "gzip");
  if (decoded.join() !== raw.join()) throw new Error("signed bytes changed");
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode("secret"),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = [
    ...new Uint8Array(await crypto.subtle.sign("HMAC", key, raw)),
  ].map((b) => b.toString(16).padStart(2, "0")).join("");
  if (
    !await verifyStreamSignature(decoded, signature, "secret") ||
    await verifyStreamSignature(compressed, signature, "secret")
  ) throw new Error("wrong signature boundary");
});
Deno.test("middleware-decoded gzip header and small uncompressed events remain valid", async () => {
  for (const encoding of [null, "identity", "gzip"]) {
    if ((await decodeStreamWebhookBody(raw, encoding)).join() !== raw.join()) {
      throw new Error("plain bytes changed");
    }
  }
});
Deno.test("gzip magic bytes determine decoding even without envelope header", async () => {
  if (
    (await decodeStreamWebhookBody(await gzip(raw), null)).join() !== raw.join()
  ) throw new Error("compression not detected");
});
Deno.test("expanded gzip payload is bounded, not just its compressed size", async () => {
  try {
    await decodeStreamWebhookBody(
      await gzip(new Uint8Array(100000)),
      "gzip",
      1000,
    );
    throw new Error("expanded payload accepted");
  } catch (e) {
    if (!(e instanceof BodyTooLarge)) throw e;
  }
});
Deno.test("invalid gzip and unsupported encodings are rejected", async () => {
  for (
    const [bytes, encoding] of [[new Uint8Array([0x1f, 0x8b, 1]), "gzip"], [
      raw,
      "br",
    ]] as const
  ) {
    let rejected = false;
    try {
      await decodeStreamWebhookBody(bytes, encoding);
    } catch (e) {
      rejected = true;
      if (encoding === "br" && !(e instanceof UnsupportedWebhookEncoding)) {
        throw e;
      }
    }
    if (!rejected) throw new Error("invalid encoding accepted");
  }
});
