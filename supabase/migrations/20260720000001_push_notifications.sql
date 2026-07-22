-- L-17: private Android push tokens plus a transactional notification outbox.
-- A Database Webhook invokes the send-push Edge Function after an event row is
-- inserted. The webhook is deliberately asynchronous: FCM outages must never
-- roll back message persistence or invite claims.

create table public.push_device_tokens (
  token text primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  platform text not null check (platform = 'android'),
  previews_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  constraint push_device_tokens_token_length
    check (length(token) between 20 and 4096)
);

create index push_device_tokens_user_idx
  on public.push_device_tokens (user_id);

alter table public.push_device_tokens enable row level security;
revoke all on table public.push_device_tokens from public, anon, authenticated;
grant select, insert, update, delete on table public.push_device_tokens
  to service_role;

create table public.push_notification_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null
    check (event_type in ('chat_message', 'invite_claimed')),
  source_key text not null,
  recipient_id uuid not null references public.profiles (id) on delete cascade,
  actor_id uuid references public.profiles (id) on delete set null,
  chat_id uuid not null references public.chats (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'completed')),
  attempts integer not null default 0 check (attempts >= 0),
  last_error text,
  created_at timestamptz not null default now(),
  processing_started_at timestamptz,
  completed_at timestamptz,
  unique (event_type, source_key, recipient_id)
);

create index push_notification_events_pending_idx
  on public.push_notification_events (status, created_at);

alter table public.push_notification_events enable row level security;
revoke all on table public.push_notification_events
  from public, anon, authenticated;
grant select, insert, update, delete on table public.push_notification_events
  to service_role;

create table public.push_notification_deliveries (
  event_id uuid not null references public.push_notification_events (id)
    on delete cascade,
  token_hash text not null check (token_hash ~ '^[0-9a-f]{64}$'),
  status text not null check (status in ('sending', 'sent', 'stale', 'failed')),
  provider_code text,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  primary key (event_id, token_hash)
);

alter table public.push_notification_deliveries enable row level security;
revoke all on table public.push_notification_deliveries
  from public, anon, authenticated;
grant select, insert, update, delete on table public.push_notification_deliveries
  to service_role;

create or replace function public.register_push_token(
  p_token text,
  p_platform text,
  p_previews_enabled boolean
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_signed_in';
  end if;
  if not public.is_account_active(v_uid) then
    raise exception 'account_suspended';
  end if;
  if p_platform <> 'android'
      or p_token is null
      or length(p_token) not between 20 and 4096 then
    raise exception 'invalid_push_token';
  end if;

  insert into public.push_device_tokens (
    token,
    user_id,
    platform,
    previews_enabled
  ) values (
    p_token,
    v_uid,
    p_platform,
    coalesce(p_previews_enabled, true)
  )
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        previews_enabled = excluded.previews_enabled,
        updated_at = now(),
        last_seen_at = now();
end;
$$;

revoke all on function public.register_push_token(text, text, boolean)
  from public, anon;
grant execute on function public.register_push_token(text, text, boolean)
  to authenticated;

create or replace function public.unregister_push_token(p_token text)
returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  delete from public.push_device_tokens
  where token = p_token and user_id = auth.uid();
$$;

revoke all on function public.unregister_push_token(text) from public, anon;
grant execute on function public.unregister_push_token(text) to authenticated;

create or replace function public.enqueue_message_push()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.push_notification_events (
    event_type,
    source_key,
    recipient_id,
    actor_id,
    chat_id
  )
  select
    'chat_message',
    new.id::text,
    member.user_id,
    new.sender_id,
    new.chat_id
  from public.chat_members member
  where member.chat_id = new.chat_id
    and member.user_id <> new.sender_id
  on conflict (event_type, source_key, recipient_id) do nothing;
  return new;
end;
$$;

revoke all on function public.enqueue_message_push()
  from public, anon, authenticated;

create trigger enqueue_message_push
  after insert on public.messages
  for each row execute function public.enqueue_message_push();

create or replace function public.enqueue_invite_claimed_push()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if old.used_at is null
      and new.used_at is not null
      and new.used_by_user_id is not null
      and new.resulting_chat_id is not null then
    insert into public.push_notification_events (
      event_type,
      source_key,
      recipient_id,
      actor_id,
      chat_id
    ) values (
      'invite_claimed',
      new.token,
      new.inviter_user_id,
      new.used_by_user_id,
      new.resulting_chat_id
    )
    on conflict (event_type, source_key, recipient_id) do nothing;
  end if;
  return new;
end;
$$;

revoke all on function public.enqueue_invite_claimed_push()
  from public, anon, authenticated;

create trigger enqueue_invite_claimed_push
  after update of used_at, used_by_user_id, resulting_chat_id
  on public.invites
  for each row execute function public.enqueue_invite_claimed_push();

-- Claims one webhook event. A five-minute lease permits an operational retry
-- after a worker crash without allowing concurrent workers to fan out twice.
create or replace function public.claim_push_notification_event(p_event_id uuid)
returns table (
  event_id uuid,
  event_type text,
  recipient_id uuid,
  actor_name text,
  interface_language text,
  chat_id uuid,
  original_body text
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  return query
  with claimed as (
    update public.push_notification_events event
    set status = 'processing',
        attempts = event.attempts + 1,
        processing_started_at = now(),
        last_error = null
    where event.id = p_event_id
      and (
        event.status = 'pending'
        or (
          event.status = 'processing'
          and event.processing_started_at < now() - interval '5 minutes'
        )
      )
    returning event.*
  )
  select
    claimed.id,
    claimed.event_type,
    claimed.recipient_id,
    coalesce(nullif(trim(profile.display_name), ''), 'Blab'),
    coalesce(recipient.interface_language, 'en'),
    claimed.chat_id,
    case
      when claimed.event_type = 'chat_message' then message.body
      else null
    end
  from claimed
  left join public.profiles profile on profile.id = claimed.actor_id
  left join public.profiles recipient on recipient.id = claimed.recipient_id
  left join public.messages message
    on claimed.event_type = 'chat_message'
    and message.id::text = claimed.source_key;
end;
$$;

revoke all on function public.claim_push_notification_event(uuid)
  from public, anon, authenticated;
grant execute on function public.claim_push_notification_event(uuid)
  to service_role;

create or replace function public.reserve_push_notification_delivery(
  p_event_id uuid,
  p_token_hash text
) returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_inserted integer;
begin
  if p_token_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid_token_hash';
  end if;
  insert into public.push_notification_deliveries (
    event_id,
    token_hash,
    status
  ) values (
    p_event_id,
    p_token_hash,
    'sending'
  ) on conflict (event_id, token_hash) do nothing;
  get diagnostics v_inserted = row_count;
  return v_inserted = 1;
end;
$$;

revoke all on function public.reserve_push_notification_delivery(uuid, text)
  from public, anon, authenticated;
grant execute on function public.reserve_push_notification_delivery(uuid, text)
  to service_role;

create or replace function public.finish_push_notification_delivery(
  p_event_id uuid,
  p_token_hash text,
  p_status text,
  p_provider_code text default null
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if p_status not in ('sent', 'stale', 'failed') then
    raise exception 'invalid_delivery_status';
  end if;
  update public.push_notification_deliveries
  set status = p_status,
      provider_code = left(p_provider_code, 80),
      completed_at = now()
  where event_id = p_event_id and token_hash = p_token_hash;
end;
$$;

revoke all on function public.finish_push_notification_delivery(
  uuid, text, text, text
) from public, anon, authenticated;
grant execute on function public.finish_push_notification_delivery(
  uuid, text, text, text
) to service_role;

create or replace function public.complete_push_notification_event(
  p_event_id uuid,
  p_last_error text default null
) returns void
language sql
security definer
set search_path = public, pg_temp
as $$
  update public.push_notification_events
  set status = 'completed',
      completed_at = now(),
      last_error = left(p_last_error, 160)
  where id = p_event_id and status = 'processing';
$$;

revoke all on function public.complete_push_notification_event(uuid, text)
  from public, anon, authenticated;
grant execute on function public.complete_push_notification_event(uuid, text)
  to service_role;

comment on table public.push_device_tokens is
  'FCM routing tokens. App clients can mutate only through owner-scoped RPCs and can never enumerate rows.';
comment on table public.push_notification_events is
  'Transactional outbox for asynchronous FCM delivery; contains no message body.';
comment on table public.push_notification_deliveries is
  'Idempotency/audit rows keyed by a one-way token hash; never stores token or message content.';
