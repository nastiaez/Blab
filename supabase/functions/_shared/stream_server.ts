// Stream credentials and signing remain server-only.
const encoder = new TextEncoder();

function base64url(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes)).replaceAll("+", "-")
    .replaceAll("/", "_").replace(/=+$/, "");
}

export async function signStreamToken(
  secret: string,
  claims: Record<string, unknown>,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const header = base64url(
    encoder.encode(JSON.stringify({ alg: "HS256", typ: "JWT" })),
  );
  const payload = base64url(encoder.encode(JSON.stringify(claims)));
  const unsigned = `${header}.${payload}`;
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(unsigned),
  );
  return `${unsigned}.${base64url(new Uint8Array(signature))}`;
}

export class StreamServer {
  constructor(
    readonly apiKey: string,
    private readonly secret: string,
    private readonly fetcher: typeof fetch = fetch,
  ) {}

  async userToken(userId: string, nowSeconds: number): Promise<string> {
    if (!userId || !Number.isSafeInteger(nowSeconds)) {
      throw new Error("invalid_identity");
    }
    return await signStreamToken(this.secret, {
      user_id: userId,
      iat: nowSeconds,
      exp: nowSeconds + 3600,
    });
  }

  async uploadImage(
    chatId: string,
    actorId: string,
    file: File,
  ): Promise<string> {
    return this.uploadAsset(chatId, actorId, file, "image");
  }

  async uploadFile(
    chatId: string,
    actorId: string,
    file: File,
  ): Promise<string> {
    return this.uploadAsset(chatId, actorId, file, "file");
  }

  private async uploadAsset(
    chatId: string,
    actorId: string,
    file: File,
    kind: "image" | "file",
  ): Promise<string> {
    const token = await signStreamToken(this.secret, { server: true });
    const form = new FormData();
    form.set("file", file);
    form.set("user", JSON.stringify({ id: actorId }));
    const url = new URL(
      `https://chat.stream-io-api.com/channels/blab/${chatId}/${kind}`,
    );
    url.searchParams.set("api_key", this.apiKey);
    const response = await this.fetcher(url, {
      method: "POST",
      headers: { Authorization: token, "Stream-Auth-Type": "jwt" },
      body: form,
      signal: AbortSignal.timeout(60000),
    });
    if (!response.ok) throw new Error(`stream_upload_http_${response.status}`);
    const result = await response.json();
    if (typeof result.file !== "string") {
      throw new Error("stream_upload_missing_file");
    }
    const asset = new URL(result.file);
    if (
      asset.protocol !== "https:" ||
      !asset.hostname.endsWith(".stream-io-cdn.com")
    ) throw new Error("stream_upload_invalid_asset");
    return result.file;
  }

  async request(
    path: string,
    body?: unknown,
    options: {
      method?: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
      query?: Record<string, string>;
    } = {},
  ): Promise<Record<string, unknown>> {
    const token = await signStreamToken(this.secret, { server: true });
    const url = new URL(`https://chat.stream-io-api.com/${path}`);
    url.searchParams.set("api_key", this.apiKey);
    for (const [key, value] of Object.entries(options.query ?? {})) {
      url.searchParams.set(key, value);
    }
    const response = await this.fetcher(
      url,
      {
        method: options.method ?? (body === undefined ? "GET" : "POST"),
        headers: {
          Authorization: token,
          "Stream-Auth-Type": "jwt",
          "Content-Type": "application/json",
        },
        body: body === undefined ? undefined : JSON.stringify(body),
        signal: AbortSignal.timeout(10000),
      },
    );
    if (!response.ok) throw new Error(`stream_http_${response.status}`);
    const result = await response.json();
    // Stream may reject a send with HTTP 201 and an ephemeral error message.
    if (result?.message?.type === "error") {
      throw new Error("stream_message_rejected");
    }
    return result;
  }
}
