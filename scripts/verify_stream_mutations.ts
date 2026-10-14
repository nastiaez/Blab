// Isolated review-fixture probe; never accepts a production app configuration.
import { StreamServer } from "../supabase/functions/_shared/stream_server.ts";
const credentialPath = Deno.args[0] ??
  "/Users/aswin/clawd/secrets/blab-stream-review.json";
const credential = JSON.parse(await Deno.readTextFile(credentialPath));
if (
  String(credential.appId) !== "1731706" || credential.mode !== "development"
) throw new Error("refusing_nonreview_app");
const server = new StreamServer(credential.apiKey, credential.apiSecret);
const actor = "00000000-0000-4000-8000-000000000901";
const chat = "00000000-0000-4000-8000-000000000904";
const messageId = "00000000-0000-4000-8000-000000000906";
const path = `messages/${messageId}`;
const read = async () =>
  (await server.request(path, undefined, {
    query: { show_deleted_message: "true" },
  })).message as Record<string, unknown>;
let current: Record<string, unknown> | null = null;
try {
  current = await read();
} catch (error) {
  if (!(error instanceof Error) || error.message !== "stream_http_404") {
    throw error;
  }
}
if (!current) {
  current = (await server.request(`channels/blab/${chat}/message`, {
    message: {
      id: messageId,
      user_id: actor,
      text: "Mutation fixture original",
    },
    skip_push: true,
    skip_enrich_url: true,
  })).message as Record<string, unknown>;
}
if (
  current.cid !== `blab:${chat}` ||
  (current.user as { id?: string })?.id !== actor
) throw new Error("fixture_identity_conflict");
if (current.deleted_at) {
  await server.request(`${path}/undelete`, { undeleted_by: actor });
}
const edited = (await server.request(path, {
  set: { text: "Mutation fixture edited" },
  user_id: actor,
  skip_enrich_url: true,
}, { method: "PUT" })).message as Record<string, unknown>;
const checks: Record<string, boolean> = {
  partial_edit: edited.text === "Mutation fixture edited",
  authoritative_edit_marker: typeof edited.message_text_updated_at === "string",
};
await server.request(path, undefined, {
  method: "DELETE",
  query: { hard: "false", deleted_by: actor },
});
const deleted = await read();
checks.soft_delete_preserves_restore_source =
  typeof deleted.deleted_at === "string" &&
  deleted.text === "Mutation fixture edited";
const restored =
  (await server.request(`${path}/undelete`, { undeleted_by: actor }))
    .message as Record<string, unknown>;
checks.undo_restores_same_identity = restored.id === messageId &&
  !restored.deleted_at && restored.text === "Mutation fixture edited";
await Deno.writeTextFile(
  "docs/qa/2026-10-14-stream-delivery/vendor-mutation-checks.json",
  JSON.stringify(
    {
      isolated_app: "1731706",
      checks,
      scope:
        "Actual server-side Stream fixtures; not the authenticated Blab command endpoint or Android acceptance",
    },
    null,
    2,
  ) + "\n",
);
console.log(
  JSON.stringify({
    passed: Object.values(checks).filter(Boolean).length,
    total: Object.keys(checks).length,
    checks,
  }),
);
if (Object.values(checks).some((value) => !value)) Deno.exit(1);
