-- Private per-device serialization; no FCM token is duplicated in the lease.
create table public.stream_push_devices (
 token_hash text primary key check(token_hash ~ '^[0-9a-f]{64}$'),
 owner_id uuid not null references public.profiles(id) on delete cascade,
 previous_owners uuid[] not null default '{}',
 action text not null check(action in ('register','unregister')),
 previews_enabled boolean not null default true,
 status text not null default 'pending' check(status in ('pending','processing','ready')),
 lease_token uuid,
 locked_at timestamptz,
 updated_at timestamptz not null default now()
);
alter table public.stream_push_devices enable row level security;
revoke all on public.stream_push_devices from public,anon,authenticated;
grant all on public.stream_push_devices to service_role;

create function public.reserve_stream_push_device(p_actor uuid,p_token text,p_action text,p_previews boolean default true)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_hash text; v_row stream_push_devices; v_existing uuid; v_previous uuid[]; v_lease uuid;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 if p_action not in ('register','unregister') or p_token is null or length(p_token) not between 20 and 4096
  or p_actor is null then raise exception 'invalid_device_operation'; end if;
 if p_action='register' and not public.is_account_active(p_actor) then raise exception 'account_not_available'; end if;
 v_hash:=encode(extensions.digest(p_token,'sha256'),'hex');
 insert into stream_push_devices(token_hash,owner_id,action,previews_enabled)
 values(v_hash,p_actor,p_action,coalesce(p_previews,true)) on conflict do nothing;
 select * into v_row from stream_push_devices where token_hash=v_hash for update;
 select user_id into v_existing from push_device_tokens where token=p_token;
 if p_action='unregister' and (v_row.owner_id<>p_actor or (v_existing is not null and v_existing<>p_actor)) then
  return jsonb_build_object('status','not_owned');
 end if;
 if v_row.status='processing' and v_row.locked_at>now()-interval '2 minutes' then
  return jsonb_build_object('status','in_flight');
 end if;
 select coalesce(array_agg(distinct x),'{}'::uuid[]) into v_previous
 from unnest(v_row.previous_owners||array[v_row.owner_id,v_existing]) x where x is not null;
 if cardinality(v_previous)>8 then raise exception 'device_recovery_required'; end if;
 v_lease:=gen_random_uuid();
 update stream_push_devices set owner_id=p_actor,previous_owners=v_previous,action=p_action,
  previews_enabled=coalesce(p_previews,true),status='processing',lease_token=v_lease,locked_at=now(),updated_at=now()
 where token_hash=v_hash;
 return jsonb_build_object('status','reserved','actorId',p_actor,'previousOwners',v_previous,'leaseToken',v_lease);
end; $$;
revoke all on function public.reserve_stream_push_device(uuid,text,text,boolean) from public,anon,authenticated;
grant execute on function public.reserve_stream_push_device(uuid,text,text,boolean) to service_role;

create function public.finish_stream_push_device(p_actor uuid,p_token text,p_lease uuid,p_success boolean)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare v_hash text; v_row stream_push_devices;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 v_hash:=encode(extensions.digest(p_token,'sha256'),'hex');
 select * into v_row from stream_push_devices where token_hash=v_hash for update;
 if not found or v_row.owner_id<>p_actor or v_row.lease_token is distinct from p_lease or v_row.status<>'processing' then return false; end if;
 if p_success then
  if v_row.action='register' then
   insert into push_device_tokens(token,user_id,platform,previews_enabled)
    values(p_token,p_actor,'android',v_row.previews_enabled)
    on conflict(token) do update set user_id=excluded.user_id,previews_enabled=excluded.previews_enabled,
     updated_at=now(),last_seen_at=now();
  else
   delete from push_device_tokens where token=p_token and user_id=p_actor;
  end if;
 end if;
 update stream_push_devices set status=case when p_success then 'ready' else 'pending' end,
  previous_owners=case when p_success then '{}'::uuid[] else previous_owners end,
  lease_token=null,locked_at=null,updated_at=now() where token_hash=v_hash;
 return true;
end; $$;
revoke all on function public.finish_stream_push_device(uuid,text,uuid,boolean) from public,anon,authenticated;
grant execute on function public.finish_stream_push_device(uuid,text,uuid,boolean) to service_role;
