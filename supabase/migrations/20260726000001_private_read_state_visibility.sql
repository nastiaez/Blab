-- Local unread state must persist even when public read receipts are disabled.
-- A hidden receipt clears the reader's own unread badge without exposing a
-- partner-visible read indicator.

alter table public.message_reads
  add column if not exists receipt_visible boolean not null default true;

drop policy if exists message_reads_select_member on public.message_reads;
create policy message_reads_select_member on public.message_reads
  for select to authenticated using (
    user_id = auth.uid()
    or (
      receipt_visible
      and public.is_chat_member(chat_id)
    )
  );

revoke insert on table public.message_reads from authenticated;
grant insert (message_id, user_id, chat_id, receipt_visible)
  on table public.message_reads to authenticated;
