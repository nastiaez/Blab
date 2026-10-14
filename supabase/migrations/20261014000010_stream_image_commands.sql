-- Image captions use the same identity, block, reply and retry authority.
alter table public.stream_message_commands drop constraint stream_message_commands_action_check;
alter table public.stream_message_commands add constraint stream_message_commands_action_check check(action in ('send','send_image','edit','delete','restore'));
create or replace function public.authorize_stream_message_command(
 p_request_id uuid,p_chat_id uuid,p_message_id uuid,p_action text,p_body text default null,p_reply_id uuid default null
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_uid uuid:=auth.uid(); v_hash text; v_command stream_message_commands%rowtype; v_lease uuid; v_inserted boolean; v_matched boolean;
begin
 if v_uid is null or not public.is_account_active(v_uid) or not public.is_chat_member(p_chat_id) then raise insufficient_privilege using message='chat_not_available'; end if;
 if not exists(select 1 from chat_message_transports where chat_id=p_chat_id and provider='stream' and migration_state='active') then raise exception 'stream_not_enabled'; end if;
 if p_request_id is null or p_message_id is null or p_action not in ('send','send_image','edit','delete','restore') then raise exception 'invalid_command'; end if;
 if p_action in ('send','send_image','edit') and (p_body is null or char_length(p_body)>2000 or (p_action<>'send_image' and btrim(p_body)='')) then raise exception 'invalid_message_body'; end if;
 if p_action not in ('send','send_image') and p_reply_id is not null then raise exception 'invalid_reply'; end if;
 if p_action='send_image' and not exists(select 1 from stream_media_uploads where message_id=p_message_id and chat_id=p_chat_id and actor_id=v_uid and status='ready') then raise exception 'media_not_ready'; end if;
 v_hash:=encode(digest(convert_to(jsonb_build_object('chat',p_chat_id,'message',p_message_id,'action',p_action,'body',p_body,'reply',p_reply_id)::text,'UTF8'),'sha256'),'hex');
 insert into stream_message_commands(request_id,chat_id,actor_id,message_id,action,payload_hash)
 values(p_request_id,p_chat_id,v_uid,p_message_id,p_action,v_hash) on conflict do nothing;
 v_inserted:=found;
 if v_inserted and p_action in ('send','send_image') then
   perform cm.user_id from chat_members cm where cm.chat_id=p_chat_id order by cm.user_id for share;
   select count(*)=2 and count(distinct learning_language)=1 into v_matched from chat_members where chat_id=p_chat_id;
   update stream_message_commands set languages_matched_at_send=coalesce(v_matched,false) where request_id=p_request_id;
 end if;
 select * into v_command from stream_message_commands where request_id=p_request_id for update;
 if v_command.actor_id<>v_uid or v_command.payload_hash<>v_hash then raise exception 'idempotency_conflict'; end if;
 if v_command.status='done' then return jsonb_build_object('status','done','result',v_command.result); end if;
 if p_action in ('send','send_image') then
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
 return jsonb_build_object('status','authorized','actorId',v_uid,'chatId',p_chat_id,'messageId',p_message_id,'leaseToken',v_lease,'languagesMatchedAtSend',v_command.languages_matched_at_send,
   'attachment',case when p_action='send_image' then (select attachment from stream_media_uploads where message_id=p_message_id) else null end);
end; $$;
revoke all on function public.authorize_stream_message_command(uuid,uuid,uuid,text,text,uuid) from public,anon;
grant execute on function public.authorize_stream_message_command(uuid,uuid,uuid,text,text,uuid) to authenticated;

