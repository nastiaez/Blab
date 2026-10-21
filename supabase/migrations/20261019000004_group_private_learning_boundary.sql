-- BLA-14 author-only corrections: shared legacy cache rows can contain marks.
-- Group recipients must use their private prepared/readable results instead.
create function public.group_shared_learning_visible(p_message_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select coalesce((select c.chat_kind='direct' or m.sender_id=auth.uid()
 from public.messages m join public.chats c on c.id=m.chat_id
 where m.id=p_message_id and public.is_chat_member(m.chat_id)
 and public.group_history_visible(m.chat_id,m.created_at)),false);
$$;
revoke all on function public.group_shared_learning_visible(uuid) from public,anon;
grant execute on function public.group_shared_learning_visible(uuid) to authenticated;
create policy group_learning_private on public.message_translations as restrictive
for select to authenticated using(public.group_shared_learning_visible(message_id));

create function public.guard_group_message_time() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 perform 1 from public.chats c where c.id=new.chat_id and c.chat_kind='group' for share;
 if found then
   if not exists(select 1 from public.chat_members cm where cm.chat_id=new.chat_id
    and cm.user_id=new.sender_id and cm.chat_left_at is null) then raise insufficient_privilege; end if;
   new.created_at := clock_timestamp();
 end if;
 return new;
end; $$;
create trigger a_guard_group_message_time before insert on public.messages
for each row execute function public.guard_group_message_time();
