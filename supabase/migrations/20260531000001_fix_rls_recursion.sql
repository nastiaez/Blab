-- Fix infinite-recursion in RLS: chat_members SELECT policy queried
-- chat_members through RLS, which re-triggered itself (error 42P17).
-- Wrap the membership check in a SECURITY DEFINER function that runs with
-- table owner permissions and therefore bypasses RLS on chat_members.
create or replace function public.is_chat_member(target_chat_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.chat_members
    where chat_id = target_chat_id and user_id = auth.uid()
  );
$$;

grant execute on function public.is_chat_member(uuid) to authenticated;

-- Replace every policy that referenced chat_members from inside RLS.

drop policy if exists chats_select_member on public.chats;
create policy chats_select_member on public.chats
  for select to authenticated using (public.is_chat_member(id));

drop policy if exists chat_members_select on public.chat_members;
create policy chat_members_select on public.chat_members
  for select to authenticated using (public.is_chat_member(chat_id));

drop policy if exists messages_select_member on public.messages;
create policy messages_select_member on public.messages
  for select to authenticated using (public.is_chat_member(chat_id));

drop policy if exists messages_insert_sender on public.messages;
create policy messages_insert_sender on public.messages
  for insert to authenticated with check (
    auth.uid() = sender_id and public.is_chat_member(chat_id)
  );

drop policy if exists message_reads_select_member on public.message_reads;
create policy message_reads_select_member on public.message_reads
  for select to authenticated using (public.is_chat_member(chat_id));
