-- Stream authority is explicitly per-chat. No existing chat is switched here.
create table public.chat_message_transports (
  chat_id uuid primary key references public.chats(id) on delete cascade,
  provider text not null check (provider in ('supabase','stream')),
  migration_state text not null default 'preparing' check (migration_state in ('preparing','active','rollback')),
  updated_at timestamptz not null default now()
);
alter table public.chat_message_transports enable row level security;
revoke all on public.chat_message_transports from public,anon,authenticated;
grant select on public.chat_message_transports to authenticated;
grant all on public.chat_message_transports to service_role;
create policy chat_transport_select_member on public.chat_message_transports for select to authenticated
  using (public.is_chat_member(chat_id) and public.is_account_active(auth.uid()));

create table public.stream_event_inbox (
  event_id text primary key check (length(event_id) between 1 and 200),
  body_hash text not null unique check (body_hash ~ '^[0-9a-f]{64}$'),
  chat_id uuid not null references public.chats(id) on delete cascade,
  message_id uuid not null,
  event_type text not null check (event_type in ('message.new','message.updated','message.deleted')),
  occurred_at timestamptz not null,
  received_at timestamptz not null default now(),
  status text not null default 'pending' check(status in ('pending','processing','done','failed')),
  attempts integer not null default 0,
  next_attempt_at timestamptz not null default now(),
  lease_token uuid,
  locked_at timestamptz,
  last_error text
);
alter table public.stream_event_inbox enable row level security;
revoke all on public.stream_event_inbox from public,anon,authenticated;
grant all on public.stream_event_inbox to service_role;
create index stream_event_inbox_pending on public.stream_event_inbox(next_attempt_at,received_at) where status in ('pending','processing');

create or replace function public.enqueue_stream_message_event(p_event_id text,p_body_hash text,p_event jsonb)
returns text language plpgsql security definer set search_path=public as $$
declare v_chat uuid; v_message uuid; v_existing_hash text;
begin
  if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
  if p_event->>'type' not in ('message.new','message.updated','message.deleted')
    or p_event->>'cid' not like 'blab:%' then raise exception 'invalid_stream_event'; end if;
  v_chat := substring(p_event->>'cid' from 6)::uuid;
  v_message := (p_event#>>'{message,id}')::uuid;
  if not exists(select 1 from chat_message_transports where chat_id=v_chat and provider='stream' and migration_state='active') then
    return 'ignored_unmigrated';
  end if;
  insert into stream_event_inbox(event_id,body_hash,chat_id,message_id,event_type,occurred_at)
    values(p_event_id,p_body_hash,v_chat,v_message,p_event->>'type',(p_event->>'created_at')::timestamptz)
    on conflict do nothing;
  if found then return 'queued'; end if;
  select body_hash into v_existing_hash from stream_event_inbox where event_id=p_event_id;
  if found and v_existing_hash <> p_body_hash then raise exception 'stream_event_identity_conflict'; end if;
  return 'duplicate';
end; $$;
revoke all on function public.enqueue_stream_message_event(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.enqueue_stream_message_event(text,text,jsonb) to service_role;

create or replace function public.claim_stream_message_events(p_limit integer default 8)
returns setof public.stream_event_inbox language plpgsql security definer set search_path=public as $$
begin
  if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
  update stream_event_inbox set status='failed',lease_token=null,locked_at=null,last_error='lease_retry_limit'
    where status='processing' and locked_at < now()-interval '2 minutes' and attempts>=8;
  return query
  with candidates as (
    select event_id from stream_event_inbox
    where (status='pending' and next_attempt_at <= now())
       or (status='processing' and locked_at < now()-interval '2 minutes')
    order by received_at,event_id for update skip locked limit greatest(1,least(coalesce(p_limit,8),32))
  )
  update stream_event_inbox e set status='processing',attempts=e.attempts+1,locked_at=now(),lease_token=gen_random_uuid()
    from candidates c where e.event_id=c.event_id returning e.*;
end; $$;
revoke all on function public.claim_stream_message_events(integer) from public,anon,authenticated;
grant execute on function public.claim_stream_message_events(integer) to service_role;

create or replace function public.finish_stream_message_event(p_event_id text,p_lease_token uuid,p_success boolean,p_error text default null)
returns boolean language plpgsql security definer set search_path=public as $$
begin
  if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
  update stream_event_inbox set
    status=case when p_success then 'done' when attempts>=8 then 'failed' else 'pending' end,
    next_attempt_at=now()+make_interval(secs=>least(300,power(2,least(attempts,8))::integer)),
    last_error=case when p_success then null else left(coalesce(p_error,'reconciliation_failed'),80) end,
    lease_token=null,locked_at=null
  where event_id=p_event_id and status='processing' and lease_token=p_lease_token;
  return found;
end; $$;
revoke all on function public.finish_stream_message_event(text,uuid,boolean,text) from public,anon,authenticated;
grant execute on function public.finish_stream_message_event(text,uuid,boolean,text) to service_role;
