-- BLA-14: per-member preferences apply both when queueing and when delivering.
alter table public.chat_members add column notifications_enabled boolean not null default true;

create function public.set_group_notifications(p_chat_id uuid, enabled boolean)
returns void language plpgsql security definer set search_path=public as $$
begin
  if enabled is null or not public.is_account_active(auth.uid()) then
    raise insufficient_privilege using message='group_not_available';
  end if;
  perform 1 from public.chats c where c.id=p_chat_id and c.chat_kind='group'
    and c.left_at is null for share;
  if not found then raise insufficient_privilege using message='group_not_available'; end if;
  update public.chat_members set notifications_enabled=enabled
    where chat_id=p_chat_id and user_id=auth.uid() and chat_left_at is null;
  if not found then raise insufficient_privilege using message='group_not_available'; end if;
end; $$;
revoke all on function public.set_group_notifications(uuid,boolean) from public,anon;
grant execute on function public.set_group_notifications(uuid,boolean) to authenticated;

create or replace function public.enqueue_message_push()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if exists(select 1 from chat_message_transports where chat_id=new.chat_id
    and provider='stream' and migration_state='active') then return new; end if;
  insert into push_notification_events(event_type,source_key,recipient_id,actor_id,chat_id)
    select 'chat_message',new.id::text,member.user_id,new.sender_id,new.chat_id
    from chat_members member join chats c on c.id=member.chat_id
    where member.chat_id=new.chat_id and member.user_id<>new.sender_id
      and (c.chat_kind='direct' or (member.notifications_enabled
        and member.chat_left_at is null and c.left_at is null))
    on conflict(event_type,source_key,recipient_id) do nothing;
  return new;
end; $$;

alter function public.claim_push_notification_event(uuid) rename to claim_unmuted_push_notification_event;
create function public.claim_push_notification_event(p_event_id uuid)
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
        and cm.notifications_enabled and cm.chat_left_at is null and c.left_at is null
  ) then
    update public.push_notification_events set status='completed',completed_at=now(),
      last_error='group_notifications_disabled' where id=p_event_id;
    return;
  end if;
  return query select * from public.claim_unmuted_push_notification_event(p_event_id);
end; $$;
revoke all on function public.claim_push_notification_event(uuid),
  public.claim_unmuted_push_notification_event(uuid) from public,anon,authenticated;
grant execute on function public.claim_push_notification_event(uuid) to service_role;
