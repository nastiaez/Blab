Deno.test("BLA-31 migration retains identity/history without disabling existing personal deletion", async () => {
  const sql = await Deno.readTextFile(
    new URL(
      "../../migrations/20261103000000_deleted_account_retention.sql",
      import.meta.url,
    ),
  );
  for (
    const expected of [
      "drop constraint profiles_id_fkey",
      "account_deleted_at",
      "exists(select 1 from auth.users",
      "handover_groups_before_account_erasure",
      "TG_OP='UPDATE' then return new",
      "partner_account_deleted",
      "reject_deleted_direct_stream_reservation",
      "reject_deleted_direct_media_reservation",
      "protect_deleted_identity",
    ]
  ) if (!sql.includes(expected)) throw new Error(expected);
  if (
    sql.includes("delete from public.messages") ||
    sql.includes("create or replace function public.delete_chat")
  ) throw new Error("history_or_existing_controls_changed");
  if (sql.includes("as $\n") || sql.includes("end; $;")) {
    throw new Error("invalid_dollar_quote");
  }
});

Deno.test("BLA-31 safety migration removes private rows, fences leases and retains authorization cutoffs", async () => {
  const sql = await Deno.readTextFile(
    new URL(
      "../../migrations/20261103000000_deleted_account_retention.sql",
      import.meta.url,
    ),
  );
  for (
    const expected of [
      "delete from public.message_preparation_jobs where viewer_id=old.id",
      "delete from public.message_prepared_packages where viewer_id=old.id",
      "delete from public.message_readable_variants where viewer_id=old.id",
      "delete from public.message_translation_attempts where viewer_id=old.id",
      "delete from public.pending_group_invitations",
      "delete from public.stream_message_commands",
      "delete from public.stream_media_uploads",
      "p.account_deleted_at is null",
      "cm.chat_left_at is null",
      "stream_command_is_writable",
      "private_media_cleanup_is_safe",
      "a.bucket_id=b.bucket_id",
      "cm.history_cleared_at",
      "group_history_visible",
      "deleted_direct_media_insert",
    ]
  ) if (!sql.includes(expected)) throw new Error(expected);
  const send = await Deno.readTextFile(
    new URL("../stream-message/index.ts", import.meta.url),
  );
  if (
    (send.match(/await isWritable\(\)/g) ?? []).length !== 2 ||
    !send.includes("if (createdNow)")
  ) throw new Error("in_flight_fence_missing");
  const cleanup = await Deno.readTextFile(
    new URL("../reconcile-stream-events/index.ts", import.meta.url),
  );
  if (
    !cleanup.includes('"private_media_cleanup_is_safe"') ||
    !cleanup.includes("retained_or_lease_lost")
  ) throw new Error("cleanup_fence_missing");
});
