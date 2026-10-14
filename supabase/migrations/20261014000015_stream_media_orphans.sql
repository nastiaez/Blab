-- Only never-committed uploads may enter this private cleanup queue.
create table public.stream_media_orphans (
 asset_hash text primary key check(asset_hash~'^[0-9a-f]{64}$'),
 actor_id uuid not null, chat_id uuid not null, message_id uuid not null,
 kind text not null check(kind in ('file','image')), asset_url text not null,
 status text not null default 'pending' check(status in ('pending','processing','done','failed')),
 attempts integer not null default 0,lease_token uuid,locked_at timestamptz,
 next_attempt_at timestamptz not null default now(),last_error text,
 created_at timestamptz not null default now()
);
alter table public.stream_media_orphans enable row level security;
revoke all on public.stream_media_orphans from public,anon,authenticated;
grant all on public.stream_media_orphans to service_role;

create function public.queue_stream_media_orphans(p_actor_id uuid,p_chat_id uuid,p_message_id uuid,p_media_lease uuid,p_assets jsonb)
returns integer language plpgsql security definer set search_path=public as $$
declare v_upload stream_media_uploads%rowtype;v_asset jsonb;v_url text;v_count integer:=0;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 if p_actor_id is null or p_chat_id is null or p_message_id is null or p_media_lease is null or p_assets is null or jsonb_typeof(p_assets)<>'array' or jsonb_array_length(p_assets)>2 then raise exception 'invalid_orphans'; end if;
 if jsonb_array_length(p_assets)=0 then return 0; end if;
 select * into v_upload from stream_media_uploads where message_id=p_message_id for update;
 if found and (v_upload.actor_id<>p_actor_id or v_upload.chat_id<>p_chat_id) then raise insufficient_privilege; end if;
 -- Serialize with a possibly still-running completion RPC. Never cancel a newer lease.
 if v_upload.status='processing' and v_upload.lease_token=p_media_lease then
  update stream_media_uploads set status='pending',lease_token=null,locked_at=null where message_id=p_message_id;
 end if;
 for v_asset in select * from jsonb_array_elements(p_assets) loop
  v_url:=v_asset->>'url';
  if v_asset->>'kind' is null or v_asset->>'kind' not in ('file','image') or v_url is null or length(v_url)>8192 or v_url!~'^https://[A-Za-z0-9.-]+\.stream-io-cdn\.com/' then raise exception 'invalid_asset'; end if;
  if exists(select 1 from stream_media_uploads where status='ready' and (attachment->>'asset_url'=v_url or attachment->>'thumb_url'=v_url)) then continue; end if;
  insert into stream_media_orphans(asset_hash,actor_id,chat_id,message_id,kind,asset_url)
   values(encode(extensions.digest(v_url,'sha256'),'hex'),p_actor_id,p_chat_id,p_message_id,v_asset->>'kind',v_url)
   on conflict do nothing;
  if found then v_count:=v_count+1; end if;
 end loop;
 return v_count;
end; $$;
revoke all on function public.queue_stream_media_orphans(uuid,uuid,uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.queue_stream_media_orphans(uuid,uuid,uuid,uuid,jsonb) to service_role;

create function public.claim_stream_media_orphans(p_limit integer default 4)
returns setof public.stream_media_orphans language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 update stream_media_orphans o set status='done',lease_token=null,locked_at=null,last_error=null
  where status in ('pending','processing') and exists(select 1 from stream_media_uploads u where u.status='ready' and (u.attachment->>'asset_url'=o.asset_url or u.attachment->>'thumb_url'=o.asset_url));
 update stream_media_orphans set status='failed',lease_token=null,locked_at=null,last_error='retry_limit'
  where status='processing' and locked_at<now()-interval '2 minutes' and attempts>=16;
 return query with available as (
  select o.asset_hash from stream_media_orphans o
  where ((o.status='pending' and o.next_attempt_at<=now()) or (o.status='processing' and o.locked_at<now()-interval '2 minutes'))
   and o.attempts<16 and not exists(select 1 from stream_media_uploads u where u.message_id=o.message_id and u.status='processing')
  order by o.created_at,o.asset_hash for update of o skip locked limit greatest(1,least(coalesce(p_limit,4),4))
 ) update stream_media_orphans o set status='processing',attempts=o.attempts+1,lease_token=gen_random_uuid(),locked_at=now()
 from available a where o.asset_hash=a.asset_hash returning o.*;
end; $$;
revoke all on function public.claim_stream_media_orphans(integer) from public,anon,authenticated;
grant execute on function public.claim_stream_media_orphans(integer) to service_role;

create function public.finish_stream_media_orphan(p_asset_hash text,p_lease_token uuid,p_success boolean)
returns boolean language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 update stream_media_orphans set status=case when p_success then 'done' when attempts>=16 then 'failed' else 'pending' end,
  lease_token=null,locked_at=null,next_attempt_at=now()+least(interval '1 hour',interval '15 seconds'*power(2,least(attempts,8))),
  last_error=case when p_success then null else 'asset_delete_unavailable' end
 where asset_hash=p_asset_hash and lease_token=p_lease_token and status='processing';
 return found;
end; $$;
revoke all on function public.finish_stream_media_orphan(text,uuid,boolean) from public,anon,authenticated;
grant execute on function public.finish_stream_media_orphan(text,uuid,boolean) to service_role;

create or replace function public.reserve_stream_media_upload(p_chat_id uuid,p_message_id uuid,p_source_hash text,p_preview_hash text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_uid uuid:=auth.uid(); v_upload stream_media_uploads%rowtype; v_lease uuid;
begin
 if v_uid is null or not is_account_active(v_uid) or not is_chat_member(p_chat_id) then raise insufficient_privilege using message='chat_not_available'; end if;
 if not exists(select 1 from chat_message_transports where chat_id=p_chat_id and provider='stream' and migration_state='active') then raise exception 'stream_not_enabled'; end if;
 if p_message_id is null or coalesce(p_source_hash,'') !~ '^[0-9a-f]{64}$' or coalesce(p_preview_hash,'') !~ '^[0-9a-f]{64}$' then raise exception 'invalid_media_identity'; end if;
 if exists(select 1 from stream_media_orphans where message_id=p_message_id and status in ('pending','processing','failed')) then raise exception 'upload_cleanup_pending'; end if;
 if exists(select 1 from messages where id=p_message_id and (chat_id<>p_chat_id or sender_id<>v_uid or message_type<>'image')) then raise insufficient_privilege using message='message_not_available'; end if;
 if exists(select 1 from chat_members a join chat_members b on b.chat_id=a.chat_id and b.user_id<>a.user_id join blocks blocked on (blocked.blocker_id=a.user_id and blocked.blocked_id=b.user_id) or (blocked.blocker_id=b.user_id and blocked.blocked_id=a.user_id) where a.chat_id=p_chat_id and a.user_id=v_uid) then raise exception 'chat_blocked'; end if;
 insert into stream_media_uploads(message_id,chat_id,actor_id,source_hash,preview_hash)
 values(p_message_id,p_chat_id,v_uid,p_source_hash,p_preview_hash) on conflict do nothing;
 select * into v_upload from stream_media_uploads where message_id=p_message_id for update;
 if v_upload.actor_id<>v_uid or v_upload.chat_id<>p_chat_id or v_upload.source_hash<>p_source_hash or v_upload.preview_hash<>p_preview_hash then raise exception 'idempotency_conflict'; end if;
 if v_upload.status='ready' then return jsonb_build_object('status','ready','attachment',v_upload.attachment); end if;
 if v_upload.status='processing' and v_upload.locked_at>now()-interval '2 minutes' then return jsonb_build_object('status','in_flight'); end if;
 v_lease:=gen_random_uuid();
 update stream_media_uploads set status='processing',lease_token=v_lease,locked_at=now() where message_id=p_message_id;
 return jsonb_build_object('status','authorized','actorId',v_uid,'leaseToken',v_lease);
end; $$;
