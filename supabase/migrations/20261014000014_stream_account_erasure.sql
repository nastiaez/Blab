-- Durable deletion survives auth/profile cascades and asynchronous vendor tasks.
create table public.stream_account_erasure (
 user_id uuid primary key,
 status text not null default 'pending' check(status in ('pending','processing','done','failed')),
 task_id text,
 attempts integer not null default 0,
 lease_token uuid,
 locked_at timestamptz,
 next_attempt_at timestamptz not null default now(),
 last_error text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
alter table public.stream_account_erasure enable row level security;
revoke all on public.stream_account_erasure from public,anon,authenticated;
grant all on public.stream_account_erasure to service_role;

create function public.queue_stream_account_erasure(p_user_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' and pg_trigger_depth()=0 then raise insufficient_privilege; end if;
 if p_user_id is null then raise exception 'invalid_identity'; end if;
 insert into stream_account_erasure(user_id) values(p_user_id) on conflict do nothing;
end; $$;
revoke all on function public.queue_stream_account_erasure(uuid) from public,anon,authenticated;
grant execute on function public.queue_stream_account_erasure(uuid) to service_role;

create function public.capture_stream_account_erasure()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 perform queue_stream_account_erasure(old.id);
 return old;
end; $$;
revoke all on function public.capture_stream_account_erasure() from public,anon,authenticated;
create trigger capture_stream_account_erasure before delete on auth.users
 for each row execute function public.capture_stream_account_erasure();

create function public.claim_stream_account_erasure(p_limit integer default 4)
returns setof public.stream_account_erasure language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 update stream_account_erasure set status='failed',lease_token=null,locked_at=null,last_error='retry_limit'
 where status='processing' and locked_at<now()-interval '2 minutes' and attempts>=16;
 return query with available as (
  select e.user_id from stream_account_erasure e
  where not exists(select 1 from auth.users u where u.id=e.user_id)
   and ((e.status='pending' and e.next_attempt_at<=now()) or
     (e.status='processing' and e.locked_at<now()-interval '2 minutes'))
   and e.attempts<16
  order by e.created_at,e.user_id for update of e skip locked
  limit greatest(1,least(coalesce(p_limit,4),4))
 ) update stream_account_erasure e set status='processing',attempts=e.attempts+1,
   lease_token=gen_random_uuid(),locked_at=now(),updated_at=now()
 from available a where e.user_id=a.user_id returning e.*;
end; $$;
revoke all on function public.claim_stream_account_erasure(integer) from public,anon,authenticated;
grant execute on function public.claim_stream_account_erasure(integer) to service_role;

create function public.finish_stream_account_erasure(p_user_id uuid,p_lease_token uuid,p_task_id text,p_done boolean,p_error text default null)
returns boolean language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 if p_task_id is not null and (length(p_task_id)>200 or p_task_id!~'^[A-Za-z0-9_-]+$') then raise exception 'invalid_task'; end if;
 if p_error is not null and p_error!~'^[a-z_]{1,64}$' then raise exception 'invalid_error'; end if;
 update stream_account_erasure set
  status=case when p_done then 'done' when attempts>=16 then 'failed' else 'pending' end,
  task_id=coalesce(p_task_id,task_id),lease_token=null,locked_at=null,updated_at=now(),
  next_attempt_at=now()+least(interval '1 hour',interval '15 seconds'*power(2,least(attempts,8))),
  last_error=case when p_done then null else p_error end
 where user_id=p_user_id and lease_token=p_lease_token and status='processing'
   and not exists(select 1 from auth.users u where u.id=p_user_id);
 return found;
end; $$;
revoke all on function public.finish_stream_account_erasure(uuid,uuid,text,boolean,text) from public,anon,authenticated;
grant execute on function public.finish_stream_account_erasure(uuid,uuid,text,boolean,text) to service_role;
