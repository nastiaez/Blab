-- Do not deliver an old queued group push after the recipient rejoins.
create or replace function public.claim_push_notification_event(p_event_id uuid)
returns table(event_id uuid,event_type text,recipient_id uuid,actor_name text,
  interface_language text,chat_id uuid,original_body text)
language plpgsql security definer set search_path=public,pg_temp as $$
declare e public.push_notification_events%rowtype;
begin
  select * into e from public.push_notification_events where id=p_event_id for update;
  if not found then return; end if;
  if e.event_type='chat_message' and exists(select 1 from public.chats c
    where c.id=e.chat_id and c.chat_kind='group') and not exists(
      select 1 from public.chat_members cm join public.chats c on c.id=cm.chat_id
      where cm.chat_id=e.chat_id and cm.user_id=e.recipient_id
        and cm.notifications_enabled and cm.chat_left_at is null and c.left_at is null and exists(
          select 1 from public.messages m where m.id::text=e.source_key
            and m.chat_id=cm.chat_id and m.created_at>=cm.joined_at
            and m.message_type<>'group_joined')
  ) then
    update public.push_notification_events set status='completed',completed_at=now(),
      last_error='group_notifications_disabled' where id=p_event_id;
    return;
  end if;
  return query select * from public.claim_unmuted_push_notification_event(p_event_id);
end; $$;
