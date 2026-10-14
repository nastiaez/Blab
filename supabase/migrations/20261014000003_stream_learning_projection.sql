-- A read-only learning-source projection, not an independently writable chat.
create table public.stream_message_versions (
  message_id uuid primary key references public.messages(id) on delete cascade,
  canonical_version timestamptz not null,
  snapshot_hash text not null check(snapshot_hash ~ '^[0-9a-f]{64}$')
);
alter table public.stream_message_versions enable row level security;
revoke all on public.stream_message_versions from public,anon,authenticated;
grant all on public.stream_message_versions to service_role;

create or replace function public.enforce_stream_projection_authority()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_chat uuid;
begin
  v_chat := case when TG_OP='DELETE' then old.chat_id else new.chat_id end;
  if auth.role() = 'authenticated' and exists(select 1 from chat_message_transports
    where chat_id=v_chat and provider='stream' and migration_state='active') then
    raise exception 'stream_message_server_owned';
  end if;
  if TG_OP='DELETE' then return old; end if;
  return new;
end; $$;
revoke all on function public.enforce_stream_projection_authority() from public,anon,authenticated;
create trigger a_enforce_stream_projection_authority before insert or update or delete on public.messages
  for each row execute function public.enforce_stream_projection_authority();

create or replace function public.apply_stream_message_snapshot(p_chat_id uuid,p_snapshot jsonb)
returns text language plpgsql security definer set search_path=public,extensions as $$
declare
  v_id uuid := (p_snapshot->>'id')::uuid;
  v_sender uuid := (p_snapshot#>>'{user,id}')::uuid;
  v_created timestamptz := (p_snapshot->>'created_at')::timestamptz;
  v_updated timestamptz := (p_snapshot->>'updated_at')::timestamptz;
  v_deleted timestamptz := nullif(p_snapshot->>'deleted_at','')::timestamptz;
  v_edited timestamptz := nullif(p_snapshot->>'message_text_updated_at','')::timestamptz;
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
  v_version := greatest(v_created,v_updated,v_deleted,v_edited);
  v_hash := encode(digest(convert_to(jsonb_build_object('body',v_body,'type',v_type,'reply',v_reply,'deleted',v_deleted,'edited',v_edited)::text,'UTF8'),'sha256'),'hex');
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
  insert into messages(id,chat_id,sender_id,body,message_type,created_at,edited_at,deleted_at,reply_to)
    values(v_id,p_chat_id,v_sender,v_body,v_type,v_created,v_edited,v_deleted,v_reply)
    on conflict(id) do update set body=excluded.body,message_type=excluded.message_type,
      edited_at=excluded.edited_at,deleted_at=excluded.deleted_at,reply_to=excluded.reply_to;
  -- Reconcile historical learning eras, not client-supplied match metadata.
  select count(*)=2 and count(distinct era.learning_language)=1 into v_matched
    from chat_members cm cross join lateral resolve_message_learning_era(v_id,cm.user_id) era where cm.chat_id=p_chat_id;
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

-- Stream owns chat-message push for migrated chats; learning projection writes
-- must not generate a second notification. Invite notifications stay unchanged.
create or replace function public.enqueue_message_push()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if exists(select 1 from chat_message_transports where chat_id=new.chat_id and provider='stream' and migration_state='active') then return new; end if;
  insert into push_notification_events(event_type,source_key,recipient_id,actor_id,chat_id)
    select 'chat_message',new.id::text,member.user_id,new.sender_id,new.chat_id from chat_members member
    where member.chat_id=new.chat_id and member.user_id<>new.sender_id
    on conflict(event_type,source_key,recipient_id) do nothing;
  return new;
end; $$;
revoke all on function public.enqueue_message_push() from public,anon,authenticated;
