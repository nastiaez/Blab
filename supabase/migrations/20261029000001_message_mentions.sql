-- BLA-36: structured identity is separate from plain text; no push override.
alter table public.messages add column mentions jsonb not null default '[]'::jsonb;
grant update (mentions) on public.messages to authenticated;

create function public.validate_message_mentions(p_chat uuid,p_body text,p_mentions jsonb)
returns void language plpgsql security definer set search_path=public,extensions as $$
declare m jsonb; prev_end int:=0; pos int; label text; prefix text; units int; c text;
begin
 if jsonb_typeof(p_mentions) is distinct from 'array' or jsonb_array_length(p_mentions)>50 then raise exception 'invalid_mentions'; end if;
 for m in select value from jsonb_array_elements(p_mentions) loop
  if jsonb_typeof(m->'userId') is distinct from 'string' or jsonb_typeof(m->'label') is distinct from 'string' or jsonb_typeof(m->'start') is distinct from 'number' then raise exception 'invalid_mentions'; end if;
  pos:=(m->>'start')::int; label:=m->>'label';
  if pos<prev_end or btrim(label)='' or label ~ E'[\r\n]' then raise exception 'invalid_mentions'; end if;
  units:=0; prefix:='';
  for c in select regexp_split_to_table(p_body,'') loop
    exit when units>=pos;
    units:=units+case when ascii(c)>65535 then 2 else 1 end; prefix:=prefix||c;
  end loop;
  if units<>pos or substring(p_body from char_length(prefix)+1 for char_length(label)+1)<>'@'||label then raise exception 'invalid_mentions'; end if;
  if not exists(select 1 from chat_members where chat_id=p_chat and user_id=(m->>'userId')::uuid and chat_left_at is null) then raise exception 'mention_member_unavailable'; end if;
  prev_end:=pos+1;
  for c in select regexp_split_to_table(label,'') loop prev_end:=prev_end+case when ascii(c)>65535 then 2 else 1 end; end loop;
 end loop;
end; $$;
revoke all on function public.validate_message_mentions(uuid,text,jsonb) from public,anon,authenticated;

create function public.check_message_mentions() returns trigger language plpgsql security definer set search_path=public,extensions as $$
begin
 -- Server projection retains historical identity even after member departure.
 if auth.role() is distinct from 'service_role' then
  if TG_OP='INSERT' or new.mentions is distinct from old.mentions or new.body is distinct from old.body then
   perform public.validate_message_mentions(new.chat_id,new.body,new.mentions);
  end if;
 end if;
 return new;
end; $$;
create trigger validate_message_mentions before insert or update on public.messages for each row execute function public.check_message_mentions();

drop function public.authorize_stream_message_command(uuid,uuid,uuid,text,text,uuid);
create or replace function public.authorize_stream_message_command(
 p_request_id uuid,p_chat_id uuid,p_message_id uuid,p_action text,p_body text default null,p_reply_id uuid default null,p_mentions jsonb default '[]'::jsonb
) returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare v_uid uuid:=auth.uid(); v_hash text; v_command stream_message_commands%rowtype; v_lease uuid; v_inserted boolean; v_matched boolean;
begin
 if v_uid is null or not public.is_account_active(v_uid) or not public.is_chat_member(p_chat_id) then raise insufficient_privilege using message='chat_not_available'; end if;
 if not exists(select 1 from chat_message_transports where chat_id=p_chat_id and provider='stream' and migration_state='active') then raise exception 'stream_not_enabled'; end if;
 if p_request_id is null or p_message_id is null or p_action not in ('send','send_image','edit','delete','restore') then raise exception 'invalid_command'; end if;
 if p_action in ('send','send_image','edit') and (p_body is null or char_length(p_body)>2000 or (p_action<>'send_image' and btrim(p_body)='')) then raise exception 'invalid_message_body'; end if;
 if p_action not in ('send','send_image') and p_reply_id is not null then raise exception 'invalid_reply'; end if;
 if p_action in ('send','edit') then perform public.validate_message_mentions(p_chat_id,p_body,p_mentions); end if;
 if p_action='send_image' and not exists(select 1 from stream_media_uploads where message_id=p_message_id and chat_id=p_chat_id and actor_id=v_uid and status='ready') then raise exception 'media_not_ready'; end if;
 v_hash:=encode(digest(convert_to(jsonb_build_object('chat',p_chat_id,'message',p_message_id,'action',p_action,'body',p_body,'reply',p_reply_id)::text || case when p_mentions='[]'::jsonb then '' else p_mentions::text end,'UTF8'),'sha256'),'hex');
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
revoke all on function public.authorize_stream_message_command(uuid,uuid,uuid,text,text,uuid,jsonb) from public,anon;
grant execute on function public.authorize_stream_message_command(uuid,uuid,uuid,text,text,uuid,jsonb) to authenticated;


-- Preserve imported edit times across canonical reconciliation.
-- Scrub tombstones; local learning preferences remain in place across rollback.
create or replace function public.apply_stream_message_snapshot(p_chat_id uuid,p_snapshot jsonb)
returns text language plpgsql security definer set search_path=public,extensions as $$
declare
  v_id uuid := (p_snapshot->>'id')::uuid;
  v_sender uuid := (p_snapshot#>>'{user,id}')::uuid;
  v_created timestamptz := (p_snapshot->>'created_at')::timestamptz;
  v_updated timestamptz := (p_snapshot->>'updated_at')::timestamptz;
  v_deleted timestamptz := nullif(p_snapshot->>'deleted_at','')::timestamptz;
  v_edited timestamptz := coalesce(nullif(p_snapshot->>'message_text_updated_at','')::timestamptz,nullif(p_snapshot->>'blab_legacy_edited_at','')::timestamptz);
  v_reply uuid := nullif(p_snapshot->>'quoted_message_id','')::uuid;
  v_body text := coalesce(p_snapshot->>'text','');
  v_type text;
  v_version timestamptz;
  v_hash text;
  v_previous stream_message_versions%rowtype;
  v_existing messages%rowtype;
  v_matched boolean;
begin
  if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
  if not exists(select 1 from chat_message_transports where chat_id=p_chat_id and provider='stream' and migration_state='active') then return 'ignored_unmigrated'; end if;
  if p_snapshot->>'cid' is distinct from 'blab:'||p_chat_id::text
     or v_id is null or v_sender is null or v_created is null or v_updated is null
     or not exists(select 1 from chat_members where chat_id=p_chat_id and user_id=v_sender)
     or char_length(v_body)>2000 then raise exception 'invalid_stream_snapshot'; end if;
  if p_snapshot->>'type' not in ('regular','deleted') then raise exception 'invalid_stream_message_type'; end if;
  v_type := case when exists(select 1 from jsonb_array_elements(coalesce(p_snapshot->'attachments','[]'::jsonb)) a where a->>'type'='image') then 'image' else 'text' end;
  if v_type='text' and btrim(v_body)='' and v_deleted is null then raise exception 'empty_stream_message'; end if;
  if p_snapshot->>'type'='deleted' and v_deleted is null then raise exception 'missing_deletion_time'; end if;
  if v_deleted is not null then v_body := ''; end if;
  v_version := greatest(v_created,v_updated,v_deleted,v_edited);
  v_hash := encode(digest(convert_to(jsonb_build_object('body',v_body,'type',v_type,'reply',v_reply,'deleted',v_deleted,'edited',v_edited)::text || case when coalesce(p_snapshot->'blab_mentions','[]'::jsonb)='[]'::jsonb then '' else (p_snapshot->'blab_mentions')::text end,'UTF8'),'sha256'),'hex');
  perform pg_advisory_xact_lock(hashtextextended(v_id::text,0));
  select * into v_previous from stream_message_versions where message_id=v_id;
  if found then
    if v_version<v_previous.canonical_version then return 'stale'; end if;
    if v_version=v_previous.canonical_version then
      if v_hash<>v_previous.snapshot_hash then raise exception 'stream_version_conflict'; end if;
      return 'unchanged';
    end if;
  end if;
  select * into v_existing from messages where id=v_id;
  if found and (v_existing.chat_id<>p_chat_id or v_existing.sender_id<>v_sender or v_existing.created_at<>v_created) then raise exception 'stream_identity_conflict'; end if;
  if v_reply is not null and not exists(select 1 from messages where id=v_reply and chat_id=p_chat_id and created_at<=v_created) then raise exception 'reply_source_missing'; end if;
  insert into messages(id,chat_id,sender_id,body,message_type,created_at,edited_at,deleted_at,reply_to,mentions)
    values(v_id,p_chat_id,v_sender,v_body,v_type,v_created,v_edited,v_deleted,v_reply,case when v_deleted is not null then '[]'::jsonb else coalesce(p_snapshot->'blab_mentions','[]'::jsonb) end)
    on conflict(id) do update set body=excluded.body,message_type=excluded.message_type,
      edited_at=excluded.edited_at,deleted_at=excluded.deleted_at,reply_to=excluded.reply_to,mentions=excluded.mentions;
  -- Review-channel client mutations are denied. The server-minted canonical
  -- flag preserves Blab's acceptance snapshot; older imports derive eras.
  if jsonb_typeof(p_snapshot->'blab_languages_matched_at_send')='boolean' then
    v_matched := (p_snapshot->>'blab_languages_matched_at_send')::boolean;
  else
    select count(*)=2 and count(distinct era.learning_language)=1 into v_matched
      from chat_members cm cross join lateral resolve_message_learning_era(v_id,cm.user_id) era where cm.chat_id=p_chat_id;
  end if;
  update messages set languages_matched_at_send=coalesce(v_matched,false) where id=v_id;
  insert into stream_message_versions(message_id,canonical_version,snapshot_hash)
    values(v_id,v_version,v_hash) on conflict(message_id) do update set canonical_version=excluded.canonical_version,snapshot_hash=excluded.snapshot_hash;
  if v_deleted is not null then
    delete from message_translations where message_id=v_id;
    delete from message_prepared_packages where message_id=v_id;
    delete from message_preparation_jobs where message_id=v_id;
  else
    perform enqueue_message_preparation_jobs(v_id);
  end if;
  return 'applied';
end; $$;
revoke all on function public.apply_stream_message_snapshot(uuid,jsonb) from public,anon,authenticated;
grant execute on function public.apply_stream_message_snapshot(uuid,jsonb) to service_role;


-- Keep network work bounded by messages, not one HTTP roundtrip per member.
create or replace function public.prepare_translation_viewers(p_leases jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare x jsonb; r jsonb; results jsonb:='[]'::jsonb;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 if jsonb_typeof(p_leases)<>'array' or jsonb_array_length(p_leases) not between 1 and 100 then raise exception 'invalid_batch'; end if;
 for x in select value from jsonb_array_elements(p_leases) loop
  r:=public.leased_translation_action((x->>'id')::uuid,(x->>'lease')::uuid,'prepare');
  if r->>'status'='ready' then r:=r||jsonb_build_object('mentions',coalesce((select mentions from messages where id=(r->>'messageId')::uuid),'[]'::jsonb)); end if;
  results:=results||jsonb_build_array(jsonb_build_object('id',x->>'id','prepared',r));
 end loop;
 return results;
end; $$;
revoke all on function public.prepare_translation_viewers(jsonb) from public,anon,authenticated;
grant execute on function public.prepare_translation_viewers(jsonb) to service_role;

