-- Operator-only, pre-traffic migration. No chat is activated by this migration.
create table public.stream_history_cutovers (
 chat_id uuid primary key references public.chats(id) on delete cascade,
 lease_token uuid not null,
 source_hash text not null check(source_hash ~ '^[0-9a-f]{64}$'),
 state text not null check(state in ('frozen','active','rolled_back','aborted')),
 proof_hash text check(proof_hash ~ '^[0-9a-f]{64}$'),
 updated_at timestamptz not null default now()
);
alter table public.stream_history_cutovers enable row level security;
revoke all on public.stream_history_cutovers from public,anon,authenticated;
grant all on public.stream_history_cutovers to service_role;

create function public.stream_history_source_hash(p_chat_id uuid)
returns text language plpgsql security definer set search_path=public,extensions as $$
declare v_source jsonb;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 select jsonb_build_object(
  'chat',(select to_jsonb(c) from chats c where c.id=p_chat_id),
  'members',coalesce((select jsonb_agg(to_jsonb(m) order by m.user_id) from chat_members m where m.chat_id=p_chat_id),'[]'::jsonb),
  'messages',coalesce((select jsonb_agg(to_jsonb(m) order by m.id) from messages m where m.chat_id=p_chat_id),'[]'::jsonb),
  'reads',coalesce((select jsonb_agg(to_jsonb(r) order by r.message_id,r.user_id) from message_reads r join messages m on m.id=r.message_id where m.chat_id=p_chat_id),'[]'::jsonb),
  'reactions',coalesce((select jsonb_agg(to_jsonb(r) order by r.message_id,r.user_id) from message_reactions r where r.chat_id=p_chat_id),'[]'::jsonb),
  'attachments',coalesce((select jsonb_agg(to_jsonb(a) order by a.id) from message_attachments a where a.chat_id=p_chat_id),'[]'::jsonb)
 ) into v_source;
 return encode(digest(v_source::text,'sha256'),'hex');
end; $$;
revoke all on function public.stream_history_source_hash(uuid) from public,anon,authenticated;
grant execute on function public.stream_history_source_hash(uuid) to service_role;

create function public.guard_frozen_stream_history()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_row jsonb;v_chat uuid;
begin
 if auth.role() is distinct from 'authenticated' then
  if TG_OP='DELETE' then return old; end if; return new;
 end if;
 v_row:=case when TG_OP='DELETE' then to_jsonb(old) else to_jsonb(new) end;
 if TG_TABLE_NAME='message_reads' then
  select chat_id into v_chat from messages where id=(v_row->>'message_id')::uuid;
 else v_chat:=(v_row->>'chat_id')::uuid; end if;
 if exists(select 1 from stream_history_cutovers where chat_id=v_chat and state='frozen') then
  raise exception 'chat_migration_in_progress';
 end if;
 if TG_OP='UPDATE' and TG_TABLE_NAME<>'message_reads' and
  exists(select 1 from stream_history_cutovers where chat_id=(to_jsonb(old)->>'chat_id')::uuid and state='frozen') then
  raise exception 'chat_migration_in_progress';
 end if;
 if TG_OP='DELETE' then return old; end if; return new;
end; $$;
revoke all on function public.guard_frozen_stream_history() from public,anon,authenticated;
create trigger a_guard_frozen_history before insert or update or delete on messages for each row execute function guard_frozen_stream_history();
create trigger a_guard_frozen_history before insert or update or delete on chat_members for each row execute function guard_frozen_stream_history();
create trigger a_guard_frozen_history before insert or update or delete on message_reads for each row execute function guard_frozen_stream_history();
create trigger a_guard_frozen_history before insert or update or delete on message_reactions for each row execute function guard_frozen_stream_history();
create trigger a_guard_frozen_history before insert or update or delete on message_attachments for each row execute function guard_frozen_stream_history();

create function public.freeze_stream_history(p_chat_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_token uuid:=gen_random_uuid();v_hash text;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 -- Wait for existing legacy writes, then keep the snapshot stable until commit.
 lock table chats,chat_members,messages,message_reads,message_reactions,message_attachments in share row exclusive mode;
 if not exists(select 1 from chats where id=p_chat_id) or
  (select count(*) from chat_members where chat_id=p_chat_id)<>2 then raise exception 'history_pair_not_ready'; end if;
 if exists(select 1 from chat_message_transports where chat_id=p_chat_id and provider='stream' and migration_state='active') or
  exists(select 1 from stream_history_cutovers where chat_id=p_chat_id and state in ('frozen','active')) then raise exception 'history_cutover_in_progress'; end if;
 v_hash:=stream_history_source_hash(p_chat_id);
 insert into stream_history_cutovers(chat_id,lease_token,source_hash,state)
 values(p_chat_id,v_token,v_hash,'frozen') on conflict(chat_id) do update
 set lease_token=excluded.lease_token,source_hash=excluded.source_hash,state='frozen',proof_hash=null,updated_at=now();
 insert into chat_message_transports(chat_id,provider,migration_state) values(p_chat_id,'supabase','preparing')
 on conflict(chat_id) do update set provider='supabase',migration_state='preparing',updated_at=now();
 return jsonb_build_object('leaseToken',v_token,'sourceHash',v_hash);
end; $$;
revoke all on function public.freeze_stream_history(uuid) from public,anon,authenticated;
grant execute on function public.freeze_stream_history(uuid) to service_role;

create function public.finish_stream_history_cutover(p_chat_id uuid,p_lease_token uuid,p_source_hash text,p_proof_hash text,p_action text)
returns boolean language plpgsql security definer set search_path=public as $$
declare v_cutover stream_history_cutovers%rowtype;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 if p_action is null or p_action not in ('activate','abort','rollback') then raise exception 'invalid_cutover_action'; end if;
 lock table chats,chat_members,messages,message_reads,message_reactions,message_attachments,stream_message_commands,stream_event_inbox,stream_media_uploads in share row exclusive mode;
 select * into v_cutover from stream_history_cutovers where chat_id=p_chat_id for update;
 if not found or v_cutover.lease_token is distinct from p_lease_token then raise exception 'cutover_lease_mismatch'; end if;
 if (p_action in ('activate','abort') and v_cutover.state<>'frozen') or
  (p_action='rollback' and v_cutover.state<>'active') then raise exception 'cutover_state_mismatch'; end if;
 if p_action<>'abort' and (p_source_hash is distinct from v_cutover.source_hash or stream_history_source_hash(p_chat_id)<>v_cutover.source_hash) then raise exception 'history_source_changed'; end if;
 if p_action<>'abort' and (p_proof_hash is null or p_proof_hash!~'^[0-9a-f]{64}$') then raise exception 'history_readback_proof_required'; end if;
 if p_action<>'abort' and (exists(select 1 from stream_message_commands where chat_id=p_chat_id and status<>'done') or
  exists(select 1 from stream_event_inbox where chat_id=p_chat_id and status<>'done') or
  exists(select 1 from stream_media_uploads where chat_id=p_chat_id and status='processing')) then raise exception 'history_work_not_drained'; end if;
 -- Proof is an operator-held full vendor readback. Rollback proof additionally
 -- requires the vendor channel frozen and exact equality with this source.
 -- Any new activity rejects pre-traffic rollback; reconcile instead of losing it.
 update chat_message_transports set provider=case when p_action='activate' then 'stream' else 'supabase' end,
  migration_state=case when p_action='activate' then 'active' else 'rollback' end,updated_at=now() where chat_id=p_chat_id;
 update stream_history_cutovers set state=case p_action when 'activate' then 'active' when 'abort' then 'aborted' else 'rolled_back' end,
  proof_hash=p_proof_hash,updated_at=now() where chat_id=p_chat_id;
 return true;
end; $$;
revoke all on function public.finish_stream_history_cutover(uuid,uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.finish_stream_history_cutover(uuid,uuid,text,text,text) to service_role;

-- Recheck after a writer waiting behind the cutover lock resumes. An earlier
-- authorization read must not publish a reservation against old authority.
create function public.guard_stream_reservation_authority()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if (TG_OP='INSERT' or new.status='processing') and not exists(
  select 1 from chat_message_transports where chat_id=new.chat_id and provider='stream' and migration_state='active'
 ) then raise exception 'stream_not_enabled'; end if;
 return new;
end; $$;
revoke all on function public.guard_stream_reservation_authority() from public,anon,authenticated;
create trigger a_stream_reservation_authority before insert or update on stream_message_commands for each row execute function guard_stream_reservation_authority();
create trigger a_stream_reservation_authority before insert or update on stream_media_uploads for each row execute function guard_stream_reservation_authority();
