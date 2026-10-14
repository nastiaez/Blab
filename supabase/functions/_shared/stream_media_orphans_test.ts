import {
  collectUploadPair,
  eraseUploadedAsset,
} from "./stream_media_orphans.ts";
import { StreamServer } from "./stream_server.ts";
const url = "https://files.stream-io-cdn.com/owned.png";
function assert(value: unknown) {
  if (!value) throw new Error("assertion_failed");
}
async function rejects(work: Promise<unknown>) {
  let failed = false;
  try {
    await work;
  } catch {
    failed = true;
  }
  assert(failed);
}
Deno.test("partial failure waits for the other upload so no successful asset is lost", async () => {
  let release!: (value: string) => void;
  const original = new Promise<string>((resolve) => release = resolve);
  let settled = false;
  const work = collectUploadPair(
    original,
    Promise.reject(new Error("preview_failed")),
  ).then((value) => {
    settled = true;
    return value;
  });
  await Promise.resolve();
  assert(!settled);
  release(url);
  const result = await work;
  assert(
    !result.complete && result.orphans.length === 1 &&
      result.orphans[0].url === url,
  );
});
Deno.test("a thumbnail survives original-upload rejection for cleanup", async () => {
  const result = await collectUploadPair(
    Promise.reject(new Error("original_failed")),
    Promise.resolve(url),
  );
  assert(!result.complete && result.orphans[0].kind === "image");
});
Deno.test("same-byte preview shares one file and does not create a second cleanup reference", async () => {
  const result = await collectUploadPair(
    Promise.resolve(url),
    Promise.resolve(null),
  );
  assert(
    result.complete && result.asset === url && result.thumbnail === null &&
      result.orphans.length === 1,
  );
});
Deno.test("cleanup only calls vendor deletion with a validated server-owned asset", async () => {
  let calls = 0;
  const server = {
    request: async (
      path: string,
      body: unknown,
      options: { method: string; query: { url: string } },
    ) => {
      calls++;
      assert(
        path === "uploads/file" && body === undefined &&
          options.method === "DELETE" && options.query.url === url,
      );
      return {};
    },
  } as Pick<StreamServer, "request">;
  await eraseUploadedAsset(
    server,
    { kind: "file", url },
    async () => new Response(null, { status: 404 }),
  );
  assert(calls === 1);
  for (
    const bad of [
      "https://other.test/photo",
      "http://files.stream-io-cdn.com/photo",
      "https://user:secret@files.stream-io-cdn.com/photo",
    ]
  ) {
    await rejects(eraseUploadedAsset(server, { kind: "file", url: bad }));
  }
  assert(calls === 1);
});
Deno.test("missing asset settles idempotently but provider failures remain retryable", async () => {
  const missing = {
    request: async () => {
      throw new Error("stream_http_404");
    },
  } as Pick<StreamServer, "request">;
  await eraseUploadedAsset(
    missing,
    { kind: "file", url },
    async () => new Response(null, { status: 404 }),
  );
  const failed = {
    request: async () => {
      throw new Error("stream_http_503");
    },
  } as Pick<StreamServer, "request">;
  await rejects(eraseUploadedAsset(failed, { kind: "file", url }));
});
Deno.test("vendor acknowledgment does not settle a still-readable or expired CDN URL", async () => {
  const server = { request: async () => ({}) } as Pick<StreamServer, "request">;
  for (const status of [200, 403, 500]) {
    await rejects(
      eraseUploadedAsset(
        server,
        { kind: "file", url },
        async () => new Response(null, { status }),
      ),
    );
  }
  await eraseUploadedAsset(
    server,
    { kind: "file", url },
    async (input, init) => {
      assert(
        input === url && init?.method === "HEAD" && init.redirect === "error",
      );
      return new Response(null, { status: 404 });
    },
  );
});
