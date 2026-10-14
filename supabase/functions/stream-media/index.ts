import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";
import { BodyTooLarge, readBoundedBody } from "../_shared/bounded_body.ts";
import { detectedImageMime, imageByteLimit, imageHash } from "./contract.ts";
import { collectUploadPair } from "../_shared/stream_media_orphans.ts";
const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Cache-Control": "no-store",
};
const json = (value: unknown, status = 200) =>
  Response.json(value, { status, headers });
const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers });
  }
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "authentication_required" }, 401);
  }
  const url = Deno.env.get("SUPABASE_URL")!;
  const client = createClient(
    url,
    Deno.env.get("BLAB_SUPABASE_ANON_KEY") ??
      Deno.env.get("SUPABASE_ANON_KEY")!,
    {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
  const { data: identity, error: identityError } = await client.auth.getUser();
  if (identityError || !identity.user) {
    return json({ error: "authentication_required" }, 401);
  }
  let form: FormData;
  try {
    const bytes = await readBoundedBody(request, 2 * imageByteLimit + 32768);
    form = await new Response(new Uint8Array(bytes), {
      headers: { "Content-Type": request.headers.get("Content-Type") ?? "" },
    }).formData();
  } catch (error) {
    return json({
      error: error instanceof BodyTooLarge
        ? "image_too_large"
        : "invalid_media",
    }, error instanceof BodyTooLarge ? 413 : 400);
  }
  const chatId = form.get("chatId"),
    messageId = form.get("messageId"),
    original = form.get("original"),
    preview = form.get("preview") ?? original;
  if (
    typeof chatId !== "string" || !uuid.test(chatId) ||
    typeof messageId !== "string" || !uuid.test(messageId) ||
    !(original instanceof File) || !(preview instanceof File)
  ) return json({ error: "invalid_media" }, 400);
  if (
    original.size < 1 || preview.size < 1 || original.size > imageByteLimit ||
    preview.size > imageByteLimit
  ) return json({ error: "image_too_large" }, 413);
  const originalBytes = new Uint8Array(await original.arrayBuffer()),
    previewBytes = preview === original
      ? originalBytes
      : new Uint8Array(await preview.arrayBuffer());
  const mime = detectedImageMime(originalBytes),
    previewMime = detectedImageMime(previewBytes);
  if (
    !mime || !previewMime || original.type !== mime ||
    preview.type !== previewMime
  ) return json({ error: "unsupported_image" }, 415);
  const [hash, previewHash] = await Promise.all([
    imageHash(originalBytes),
    imageHash(previewBytes),
  ]);
  const { data: reservation, error: reserveError } = await client.rpc(
    "reserve_stream_media_upload",
    {
      p_chat_id: chatId,
      p_message_id: messageId,
      p_source_hash: hash,
      p_preview_hash: previewHash,
    },
  );
  if (reserveError) {
    return json(
      { error: "media_not_available" },
      reserveError.code === "42501" ? 403 : 409,
    );
  }
  if (reservation?.status === "ready") {
    return json({ attachment: reservation.attachment });
  }
  if (
    reservation?.status !== "authorized" ||
    reservation.actorId !== identity.user.id
  ) return json({ error: "upload_in_flight" }, 409);
  const admin = createClient(
    url,
    Deno.env.get("BLAB_SUPABASE_SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const extension = (type: string) =>
    type === "image/jpeg" ? "jpg" : type.split("/")[1];
  const prefix =
    `${chatId}/${identity.user.id}/${messageId}/${reservation.leaseToken}`;
  const fullPath = `${prefix}/original.${extension(mime)}`;
  const smallPath = hash === previewHash
    ? fullPath
    : `${prefix}/preview.${extension(previewMime)}`;
  const registered = await admin.rpc("register_stream_private_media", {
    p_message_id: messageId,
    p_upload_lease: reservation.leaseToken,
    p_paths: [...new Set([fullPath, smallPath])],
  });
  if (registered.error || registered.data !== true) {
    return json({ error: "upload_unavailable" }, 503);
  }
  async function upload(path: string, bytes: Uint8Array, contentType: string) {
    const { error } = await admin.storage.from("stream-private-media").upload(
      path,
      bytes,
      {
        contentType,
        cacheControl: "0",
        upsert: false,
      },
    );
    if (error) throw new Error("private_upload_failed");
    return path;
  }
  let attachment: Record<string, unknown> | null = null;
  try {
    const channel = await client.functions.invoke("stream-channel", {
      body: { chatId },
    });
    if (channel.error || channel.data?.channelId !== chatId) {
      throw new Error("media_channel_unavailable");
    }
    const uploaded = await collectUploadPair(
      upload(fullPath, originalBytes, mime),
      hash === previewHash
        ? Promise.resolve(null)
        : upload(smallPath, previewBytes, previewMime),
    );
    if (!uploaded.complete || uploaded.asset == null) {
      throw new Error("partial_upload");
    }
    attachment = {
      id: messageId,
      type: "image",
      mime_type: mime,
      file_size: original.size,
      blab_asset_id: messageId,
      blab_source_hash: hash,
      blab_preview_hash: previewHash,
      blab_storage_bucket: "stream-private-media",
      blab_storage_path: fullPath,
      blab_preview_storage_path: smallPath,
      blab_preview_mime_type: previewMime,
      blab_preview_file_size: preview.size,
    };
  } catch {
    attachment = null;
  }
  const { data: finished, error: finishError } = await admin.rpc(
    "finish_stream_media_upload",
    {
      p_message_id: messageId,
      p_lease_token: reservation.leaseToken,
      p_attachment: attachment,
    },
  );
  if (finishError || finished !== true || !attachment) {
    return json({ error: "upload_unavailable" }, 503);
  }
  return json({ attachment });
});
