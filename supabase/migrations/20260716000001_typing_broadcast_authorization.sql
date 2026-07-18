-- Private Realtime typing topics use this shape:
--   chat:<chat uuid>:typing
-- Realtime Broadcast messages are ephemeral; realtime.messages is consulted
-- only to authorize channel joins and sends and does not persist the payload.

create or replace function public.is_typing_topic_member(target_topic text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select case
    when target_topic ~
      '^chat:[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}:typing$'
    then public.is_chat_member(split_part(target_topic, ':', 2)::uuid)
    else false
  end;
$$;

revoke all on function public.is_typing_topic_member(text) from public;
grant execute on function public.is_typing_topic_member(text) to authenticated;

drop policy if exists typing_broadcast_select_member on realtime.messages;
create policy typing_broadcast_select_member
on realtime.messages
for select
to authenticated
using (
  realtime.messages.extension = 'broadcast'
  and public.is_typing_topic_member((select realtime.topic()))
);

drop policy if exists typing_broadcast_insert_member on realtime.messages;
create policy typing_broadcast_insert_member
on realtime.messages
for insert
to authenticated
with check (
  realtime.messages.extension = 'broadcast'
  and public.is_typing_topic_member((select realtime.topic()))
);
