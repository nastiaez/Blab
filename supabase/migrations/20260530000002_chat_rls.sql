alter table public.profiles enable row level security;
alter table public.chats enable row level security;
alter table public.chat_members enable row level security;
alter table public.messages enable row level security;
alter table public.message_reads enable row level security;

-- profiles: every authenticated user can read everyone's public profile
-- (display name + avatar), but only update their own row.
create policy profiles_select on public.profiles
  for select to authenticated using (true);
create policy profiles_update_self on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

-- chats: only members can see the row
create policy chats_select_member on public.chats
  for select to authenticated using (
    exists (
      select 1 from public.chat_members cm
      where cm.chat_id = chats.id and cm.user_id = auth.uid()
    )
  );
create policy chats_insert_self on public.chats
  for insert to authenticated with check (true);

-- chat_members: a user can see any membership for chats they're in,
-- and can insert themselves OR be inserted by the chat creator via RPC.
create policy chat_members_select on public.chat_members
  for select to authenticated using (
    exists (
      select 1 from public.chat_members me
      where me.chat_id = chat_members.chat_id and me.user_id = auth.uid()
    )
  );
create policy chat_members_insert_self on public.chat_members
  for insert to authenticated with check (auth.uid() = user_id);

-- messages
create policy messages_select_member on public.messages
  for select to authenticated using (
    exists (
      select 1 from public.chat_members cm
      where cm.chat_id = messages.chat_id and cm.user_id = auth.uid()
    )
  );
create policy messages_insert_sender on public.messages
  for insert to authenticated with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.chat_members cm
      where cm.chat_id = messages.chat_id and cm.user_id = auth.uid()
    )
  );
create policy messages_update_sender on public.messages
  for update to authenticated using (auth.uid() = sender_id) with check (auth.uid() = sender_id);
create policy messages_delete_sender on public.messages
  for delete to authenticated using (auth.uid() = sender_id);

-- message_reads
create policy message_reads_select_member on public.message_reads
  for select to authenticated using (
    exists (
      select 1 from public.chat_members cm
      where cm.chat_id = message_reads.chat_id and cm.user_id = auth.uid()
    )
  );
create policy message_reads_insert_self on public.message_reads
  for insert to authenticated with check (auth.uid() = user_id);
