-- BLA-14: group conversation boundaries; direct chat contracts remain intact.
create function public.group_history_visible(p_chat_id uuid, p_created_at timestamptz)
returns boolean language sql stable security definer set search_path=public as $$
 select case when c.chat_kind='direct' then true else exists(
   select 1 from public.chat_members cm where cm.chat_id=c.id
   and cm.user_id=auth.uid() and cm.chat_left_at is null
   and p_created_at>=cm.joined_at
 ) end from public.chats c where c.id=p_chat_id;
$$;
revoke all on function public.group_history_visible(uuid,timestamptz) from public,anon;
grant execute on function public.group_history_visible(uuid,timestamptz) to authenticated;
create policy messages_group_history on public.messages as restrictive for select to authenticated
using(public.group_history_visible(chat_id,created_at));

-- A private block never prevents messages to a shared group.
alter function public.is_blocked_in_chat(uuid) rename to is_blocked_in_direct_chat;
create function public.is_blocked_in_chat(p_chat_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select case when c.chat_kind='group' then false
 else public.is_blocked_in_direct_chat(p_chat_id) end
 from public.chats c where c.id=p_chat_id;
$$;
-- Policies retain function OIDs across renames: replace the insert policy too.
drop policy messages_insert_sender on public.messages;
create policy messages_insert_sender on public.messages for insert to authenticated
with check(auth.uid()=sender_id and public.is_account_active(auth.uid())
 and public.is_chat_member(chat_id) and not public.is_blocked_in_chat(chat_id));
revoke all on function public.is_blocked_in_chat(uuid) from public,anon;
grant execute on function public.is_blocked_in_chat(uuid) to authenticated;

create or replace function public.set_message_language_match()
returns trigger language plpgsql security definer set search_path=public as $$
declare n integer; langs integer;
begin
 perform cm.user_id from public.chat_members cm where cm.chat_id=new.chat_id
 order by cm.user_id for share;
 select count(*),count(distinct cm.learning_language) into n,langs
 from public.chat_members cm where cm.chat_id=new.chat_id;
 new.languages_matched_at_send := n=2 and langs=1 and exists(
   select 1 from public.chats c where c.id=new.chat_id and c.chat_kind='direct');
 return new;
end; $$;

create table public.group_message_recipients(
 message_id uuid not null references public.messages(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 primary key(message_id,user_id)
);
alter table public.group_message_recipients enable row level security;
revoke all on public.group_message_recipients from public,anon,authenticated;

create function public.snapshot_group_message_recipients()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 perform 1 from public.chats c where c.id=new.chat_id and c.chat_kind='group' for share;
 if not found then return new; end if;
 insert into public.group_message_recipients(message_id,user_id)
 select new.id,cm.user_id from public.chat_members cm
 where cm.chat_id=new.chat_id and cm.user_id<>new.sender_id
 and cm.chat_left_at is null and cm.joined_at<=new.created_at;
 return new;
end; $$;
create trigger snapshot_group_message_recipients after insert on public.messages
for each row execute function public.snapshot_group_message_recipients();

create function public.group_messages_read_by_everyone(p_chat_id uuid)
returns table(message_id uuid,user_id uuid,receipt_visible boolean)
language sql stable security definer set search_path=public as $$
 select m.id,null::uuid,true from public.messages m
 join public.chats c on c.id=m.chat_id and c.chat_kind='group'
 where m.chat_id=p_chat_id and m.sender_id=auth.uid() and m.deleted_at is null
 and public.is_account_active(auth.uid()) and public.is_chat_member(p_chat_id)
 and exists(select 1 from public.group_message_recipients s where s.message_id=m.id)
 and not exists(select 1 from public.group_message_recipients s where s.message_id=m.id
   and not exists(select 1 from public.message_reads r where r.message_id=m.id
    and r.user_id=s.user_id and r.receipt_visible));
$$;
revoke all on function public.group_messages_read_by_everyone(uuid) from public,anon;
grant execute on function public.group_messages_read_by_everyone(uuid) to authenticated;

-- Never let the old two-person Leave action close a shared group for everyone.
alter function public.leave_chat(uuid) rename to leave_direct_chat;
create function public.leave_chat(p_chat_id uuid) returns void
language plpgsql security definer set search_path=public as $$
begin
 if exists(select 1 from public.chats where id=p_chat_id and chat_kind='group')
 then raise exception 'use_group_leave_flow'; end if;
 perform public.leave_direct_chat(p_chat_id);
end; $$;
revoke all on function public.leave_chat(uuid),public.leave_direct_chat(uuid) from public,anon,authenticated;
grant execute on function public.leave_chat(uuid) to authenticated;
