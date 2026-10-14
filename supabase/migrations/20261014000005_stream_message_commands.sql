-- Short-lived idempotent commands, not a second editable message history.
create table public.stream_message_commands (
  request_id uuid primary key,
  chat_id uuid not null references public.chats(id) on delete cascade,
  actor_id uuid not null references public.profiles(id) on delete cascade,
  message_id uuid not null,
  action text not null check(action in ('send','edit','delete','restore')),
  payload_hash text not null check(payload_hash ~ '^[0-9a-f]{64}$'),
  status text not null default 'pending' check(status in ('pending','processing','done')),
  lease_token uuid,
  locked_at timestamptz,
  result jsonb,
  created_at timestamptz not null default now()
);
alter table public.stream_message_commands enable row level security;
revoke all on public.stream_message_commands from public,anon,authenticated;
grant all on public.stream_message_commands to service_role;

create or replace function public.authorize_stream_message_command(
 p_request_id uuid,p_chat_id uuid,p_message_id uuid,p_action text,p_body text default null,p_reply_id uuid default null
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_uid uuid:=auth.uid(); v_hash text; v_command stream_message_commands%rowtype; v_lease uuid;
begin
 if v_uid is null or not public.is_account_active(v_uid) or not public.is_chat_member(p_chat_id) then raise insufficient_privilege using message='chat_not_available'; end if;
 if not exists(select 1 from chat_message_transports where chat_id=p_chat_id and provider='stream' and migration_state='active') then raise exception 'stream_not_enabled'; end if;
 if p_request_id is null or p_message_id is null or p_action not in ('send','edit','delete','restore') then raise exception 'invalid_command'; end if;
 if p_action in ('send','edit') and (p_body is null or char_length(p_body)>2000 or btrim(p_body)='') then raise exception 'invalid_message_body'; end if;
 if p_action<>'send' and p_reply_id is not null then raise exception 'invalid_reply'; end if;
 v_hash:=encode(digest(convert_to(jsonb_build_object('chat',p_chat_id,'message',p_message_id,'action',p_action,'body',p_body,'reply',p_reply_id)::text,'UTF8'),'sha256'),'hex');
 insert into stream_message_commands(request_id,chat_id,actor_id,message_id,action,payload_hash)
 values(p_request_id,p_chat_id,v_uid,p_message_id,p_action,v_hash) on conflict do nothing;
 select * into v_command from stream_message_commands where request_id=p_request_id for update;
 if v_command.actor_id<>v_uid or v_command.payload_hash<>v_hash then raise exception 'idempotency_conflict'; end if;
 if v_command.status='done' then return jsonb_build_object('status','done','result',v_command.result); end if;
 if p_action='send' then
   if exists(select 1 from chat_members a join chat_members b on b.chat_id=a.chat_id and b.user_id<>a.user_id join blocks blocked on (blocked.blocker_id=a.user_id and blocked.blocked_id=b.user_id) or (blocked.blocker_id=b.user_id and blocked.blocked_id=a.user_id) where a.chat_id=p_chat_id and a.user_id=v_uid) then raise exception 'chat_blocked'; end if;
   if p_reply_id is not null and not exists(select 1 from messages where id=p_reply_id and chat_id=p_chat_id and deleted_at is null) then raise exception 'reply_not_available'; end if;
   if exists(select 1 from messages where id=p_message_id and (chat_id<>p_chat_id or sender_id<>v_uid or body<>p_body or reply_to is distinct from p_reply_id or deleted_at is not null)) then raise exception 'idempotency_conflict'; end if;
 else
   if not exists(select 1 from messages where id=p_message_id and chat_id=p_chat_id and sender_id=v_uid) then raise insufficient_privilege using message='message_not_available'; end if;
   if p_action='edit' and exists(select 1 from messages where id=p_message_id and (deleted_at is not null or created_at < now()-interval '24 hours')) then raise exception 'message_edit_not_available'; end if;
 end if;
 if v_command.status='processing' and v_command.locked_at > now()-interval '30 seconds' then return jsonb_build_object('status','in_flight'); end if;
 v_lease:=gen_random_uuid();
 update stream_message_commands set status='processing',lease_token=v_lease,locked_at=now() where request_id=p_request_id;
 return jsonb_build_object('status','authorized','actorId',v_uid,'chatId',p_chat_id,'messageId',p_message_id,'leaseToken',v_lease);
end; $$;
revoke all on function public.authorize_stream_message_command(uuid,uuid,uuid,text,text,uuid) from public,anon;
grant execute on function public.authorize_stream_message_command(uuid,uuid,uuid,text,text,uuid) to authenticated;

create or replace function public.finish_stream_message_command(p_request_id uuid,p_lease_token uuid,p_result jsonb)
returns boolean language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 update stream_message_commands set status=case when p_result is null then 'pending' else 'done' end,result=p_result,lease_token=null,locked_at=null
 where request_id=p_request_id and status='processing' and lease_token=p_lease_token;
 return found;
end; $$;
revoke all on function public.finish_stream_message_command(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.finish_stream_message_command(uuid,uuid,jsonb) to service_role;
-- Keep retry identities long enough for offline sends, without retained bodies.
do $schedule$ begin
 perform cron.schedule('blab-stream-command-retention','17 3 * * *',
   $$delete from public.stream_message_commands where status='done' and created_at<now()-interval '30 days';$$);
end; $schedule$;
