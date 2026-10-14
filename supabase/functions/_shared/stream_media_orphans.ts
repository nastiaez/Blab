import { StreamServer } from "./stream_server.ts";
export type OrphanAsset = { kind: "file" | "image"; url: string };

export async function collectUploadPair(
  original: Promise<string>,
  preview: Promise<string | null>,
) {
  const [full, small] = await Promise.allSettled([original, preview]);
  const orphans: OrphanAsset[] = [];
  if (full.status === "fulfilled") {
    orphans.push({ kind: "file", url: full.value });
  }
  if (small.status === "fulfilled" && small.value != null) {
    orphans.push({ kind: "image", url: small.value });
  }
  return {
    complete: full.status === "fulfilled" && small.status === "fulfilled",
    asset: full.status === "fulfilled" ? full.value : null,
    thumbnail: small.status === "fulfilled" ? small.value : null,
    orphans,
  };
}

export async function eraseUploadedAsset(
  server: Pick<StreamServer, "request">,
  asset: OrphanAsset,
  fetcher: typeof fetch = fetch,
) {
  const uri = new URL(asset.url);
  if (
    uri.protocol !== "https:" || uri.username || uri.password ||
    !uri.hostname.endsWith(".stream-io-cdn.com") ||
    (asset.kind !== "file" && asset.kind !== "image")
  ) throw new Error("invalid_asset");
  try {
    await server.request(`uploads/${asset.kind}`, undefined, {
      method: "DELETE",
      query: { url: asset.url },
    });
  } catch (error) {
    if (!(error instanceof Error) || error.message !== "stream_http_404") {
      throw error;
    }
  }
  // A successful deletion response can precede CDN invalidation. Do not mark
  // the durable job done while its exact issued URL still serves the asset.
  const visible = await fetcher(asset.url, {
    method: "HEAD",
    redirect: "error",
    headers: { "Cache-Control": "no-cache" },
    signal: AbortSignal.timeout(10000),
  });
  if (visible.status !== 404) throw new Error("asset_removal_unconfirmed");
}
