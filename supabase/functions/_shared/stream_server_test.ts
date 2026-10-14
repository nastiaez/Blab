import { signStreamToken, StreamServer } from "./stream_server.ts";

function decode(value: string) {
  return JSON.parse(atob(value.replaceAll("-", "+").replaceAll("_", "/")));
}

Deno.test("Stream identity token is signed and expires in one hour", async () => {
  const secret = "fixture-secret-not-a-real-credential";
  const token = await new StreamServer("fixture", secret).userToken(
    "account-a",
    1000,
  );
  const [header, payload, signature] = token.split(".");
  const claims = decode(payload);
  if (
    claims.user_id !== "account-a" || claims.iat !== 1000 ||
    claims.exp !== 4600 || claims.server
  ) {
    throw new Error("incorrect scoped claims");
  }
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const sig = Uint8Array.from(
    atob(signature.replaceAll("-", "+").replaceAll("_", "/")),
    (c) => c.charCodeAt(0),
  );
  if (
    !await crypto.subtle.verify(
      "HMAC",
      key,
      sig,
      new TextEncoder().encode(header + "." + payload),
    )
  ) throw new Error("signature rejected");
  if (
    await crypto.subtle.verify(
      "HMAC",
      key,
      sig,
      new TextEncoder().encode(header + "." + payload + "changed"),
    )
  ) throw new Error("tampering accepted");
});

Deno.test("Stream rejects empty identity and invalid time", async () => {
  for (const [id, time] of [["", 1000], ["account-a", NaN]] as const) {
    let rejected = false;
    try {
      await new StreamServer("fixture", "fixture").userToken(id, time);
    } catch {
      rejected = true;
    }
    if (!rejected) throw new Error("invalid identity accepted");
  }
});

Deno.test("Server authority is separate from user claims", async () => {
  const token = await signStreamToken("fixture", { server: true });
  const claims = decode(token.split(".")[1]);
  if (!claims.server || claims.user_id) throw new Error("authority mixed");
});

Deno.test("HTTP success carrying an error message is not accepted delivery", async () => {
  const fetcher = (() =>
    Promise.resolve(
      new Response(
        JSON.stringify({
          message: { id: "ephemeral", type: "error", text: "Rejected" },
        }),
        { status: 201 },
      ),
    )) as typeof fetch;
  try {
    await new StreamServer("fixture", "fixture", fetcher).request(
      "fixture",
      {},
    );
  } catch (error) {
    if (error instanceof Error && error.message === "stream_message_rejected") {
      return;
    }
    throw error;
  }
  throw new Error("rejected send reported as delivery");
});

Deno.test("image upload carries original bytes and identity in multipart, never JSON base64", async () => {
  const fetcher = (async (_url: unknown, init: RequestInit) => {
    if (!(init.body instanceof FormData)) {
      throw new Error("binary upload was not multipart");
    }
    const file = init.body.get("file");
    if (
      !(file instanceof File) ||
      new Uint8Array(await file.arrayBuffer()).join(",") !== "1,2,3"
    ) throw new Error("original bytes changed");
    if (init.body.get("user") !== JSON.stringify({ id: "alice" })) {
      throw new Error("upload identity lost");
    }
    const headers = new Headers(init.headers);
    if (headers.has("Content-Type")) {
      throw new Error("multipart boundary overridden");
    }
    const claims = decode(headers.get("Authorization")!.split(".")[1]);
    if (!claims.server || claims.user_id) {
      throw new Error("media upload authority mixed");
    }
    return Response.json({
      file: "https://review.stream-io-cdn.com/original.png",
    });
  }) as typeof fetch;
  const url = await new StreamServer("fixture", "fixture", fetcher).uploadImage(
    "chat",
    "alice",
    new File([new Uint8Array([1, 2, 3])], "photo.png", { type: "image/png" }),
  );
  if (!url.endsWith("/original.png")) {
    throw new Error("asset acknowledgment lost");
  }
});
