import { BodyTooLarge, readBoundedBody } from "./bounded_body.ts";
Deno.test("bounded body preserves exact signature bytes across chunks", async () => {
  const body = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(new Uint8Array([1, 2]));
      controller.enqueue(new Uint8Array([3]));
      controller.close();
    },
  });
  const actual = await readBoundedBody(
    new Request("https://example.test", { method: "POST", body }),
    3,
  );
  if (actual.join(",") !== "1,2,3") throw new Error("signature bytes changed");
});
Deno.test("body without length header is cancelled at the bound", async () => {
  let cancelled = false;
  const body = new ReadableStream<Uint8Array>({
    start(controller) {
      controller.enqueue(new Uint8Array([1, 2, 3, 4]));
    },
    cancel() {
      cancelled = true;
    },
  });
  try {
    await readBoundedBody(
      new Request("https://example.test", { method: "POST", body }),
      3,
    );
    throw new Error("oversized stream accepted");
  } catch (error) {
    if (!(error instanceof BodyTooLarge) || !cancelled) throw error;
  }
});
