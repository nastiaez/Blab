-- Private upload retry identities. Canonical attachments/files live in Stream.
create table public.stream_media_uploads (
 message_id uuid primary key,
 chat_id uuid not null references public.chats(id) on delete cascade,
 actor_id uuid not null references public.profiles(id) on delete cascade,
 source_hash text not null check(source_hash ~ '^[0-9a-f]{64}$'),
 preview_hash text not null check(preview_hash ~ '^[0-9a-f]{64}$'),
 status text not null default 'pending' check(status in ('pending','processing','ready')),
 lease_token uuid,locked_at timestamptz,attachment jsonb,
 created_at timestamptz not null default now()
);
alter table public.stream_media_uploads enable row level security;
revoke all on public.stream_media_uploads from public,anon,authenticated;
grant all on public.stream_media_uploads to service_role;

create function public.reserve_stream_media_upload(p_chat_id uuid,p_message_id uuid,p_source_hash text,p_preview_hash text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_uid uuid:=auth.uid(); v_upload stream_media_uploads%rowtype; v_lease uuid;
begin
 if v_uid is null or not is_account_active(v_uid) or not is_chat_member(p_chat_id) then raise insufficient_privilege using message='chat_not_available'; end if;
 if not exists(select 1 from chat_message_transports where chat_id=p_chat_id and provider='stream' and migration_state='active') then raise exception 'stream_not_enabled'; end if;
 if p_message_id is null or coalesce(p_source_hash,'') !~ '^[0-9a-f]{64}$' or coalesce(p_preview_hash,'') !~ '^[0-9a-f]{64}$' then raise exception 'invalid_media_identity'; end if;
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
revoke all on function public.reserve_stream_media_upload(uuid,uuid,text,text) from public,anon;
grant execute on function public.reserve_stream_media_upload(uuid,uuid,text,text) to authenticated;

create function public.finish_stream_media_upload(p_message_id uuid,p_lease_token uuid,p_attachment jsonb)
returns boolean language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 update stream_media_uploads set status=case when p_attachment is null then 'pending' else 'ready' end,
 attachment=p_attachment,lease_token=null,locked_at=null
 where message_id=p_message_id and status='processing' and lease_token=p_lease_token;
 return found;
end; $$;
revoke all on function public.finish_stream_media_upload(uuid,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.finish_stream_media_upload(uuid,uuid,jsonb) to service_role;
