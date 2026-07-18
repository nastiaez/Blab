-- L-07: make report intake, review, retention, and enforcement operational.

-- Preserve safety reports when either participant later deletes their account.
alter table public.reports
  alter column reporter_id drop not null;

alter table public.reports
  drop constraint if exists reports_reporter_id_fkey;

alter table public.reports
  add constraint reports_reporter_id_fkey
  foreign key (reporter_id) references public.profiles (id) on delete set null;

alter table public.reports
  add column target_type text not null default 'user'
    check (target_type in ('user', 'message')),
  add column status text not null default 'pending'
    check (status in ('pending', 'in_review', 'actioned', 'dismissed')),
  add column priority text not null default 'standard'
    check (priority in ('standard', 'urgent', 'child_safety')),
  add column reporter_id_snapshot uuid,
  add column reported_user_id_snapshot uuid,
  add column reporter_name_snapshot text,
  add column reported_user_name_snapshot text,
  add column message_body_snapshot text,
  add column message_created_at_snapshot timestamptz,
  add column resolved_at timestamptz,
  add column retention_until timestamptz not null
    default (now() + interval '180 days'),
  add column evidence_purged_at timestamptz;

update public.reports
set target_type = case when message_id is null then 'user' else 'message' end,
    reporter_id_snapshot = reporter_id,
    reported_user_id_snapshot = reported_user_id;

create index reports_queue_idx
  on public.reports (status, priority, created_at);
create index reports_retention_idx
  on public.reports (retention_until)
  where evidence_purged_at is null;

-- Ordinary clients submit through submit_report so they cannot spoof reporter
-- ids or attach unrelated users/messages to a report.
drop policy if exists reports_insert_own on public.reports;
drop policy if exists reports_select_own on public.reports;
revoke all on table public.reports from anon, authenticated;

create table public.account_enforcements (
  user_id uuid primary key references auth.users (id) on delete cascade,
  source_report_id uuid not null references public.reports (id) on delete restrict,
  reason text not null,
  suspended_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.account_enforcements enable row level security;
revoke all on table public.account_enforcements from public, anon, authenticated;
grant select, delete on table public.account_enforcements to service_role;

create table public.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports (id) on delete restrict,
  action text not null check (
    action in (
      'start_review',
      'dismiss',
      'escalate',
      'remove_content',
      'suspend_account',
      'restore_account',
      'note'
    )
  ),
  actor text not null,
  notes text,
  target_user_id_snapshot uuid,
  message_id_snapshot uuid,
  created_at timestamptz not null default now()
);

create index moderation_actions_report_idx
  on public.moderation_actions (report_id, created_at);

alter table public.moderation_actions enable row level security;
revoke all on table public.moderation_actions from public, anon, authenticated;
grant select, delete on table public.moderation_actions to service_role;

grant select, update, delete on table public.reports to service_role;

create or replace function public.is_account_active(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select target_user_id is not null
    and not exists (
      select 1
      from public.account_enforcements e
      where e.user_id = target_user_id
    );
$$;

revoke all on function public.is_account_active(uuid) from public;
grant execute on function public.is_account_active(uuid) to authenticated;

create or replace function public.submit_report(
  p_reason text,
  p_reported_user_id uuid,
  p_chat_id uuid,
  p_message_id uuid default null,
  p_details text default null
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_reporter_id uuid := auth.uid();
  v_report_id uuid;
  v_reporter_name text;
  v_reported_name text;
  v_message_body text;
  v_message_created_at timestamptz;
begin
  if v_reporter_id is null then
    raise exception 'not_signed_in';
  end if;
  if p_reason not in (
    'spam', 'harassment', 'hate', 'sexual', 'child_safety', 'other'
  ) then
    raise exception 'invalid_report_reason';
  end if;
  if p_chat_id is null or p_reported_user_id is null then
    raise exception 'invalid_report_target';
  end if;
  if p_reported_user_id = v_reporter_id then
    raise exception 'cannot_report_self';
  end if;
  if p_details is not null and length(p_details) > 2000 then
    raise exception 'report_details_too_long';
  end if;
  if not public.is_chat_member(p_chat_id) then
    raise exception 'report_chat_forbidden';
  end if;

  select p.display_name
    into v_reporter_name
    from public.profiles p
    where p.id = v_reporter_id;

  select p.display_name
    into v_reported_name
    from public.chat_members cm
    join public.profiles p on p.id = cm.user_id
    where cm.chat_id = p_chat_id
      and cm.user_id = p_reported_user_id;
  if not found then
    raise exception 'reported_user_not_in_chat';
  end if;

  if p_message_id is not null then
    select m.body, m.created_at
      into v_message_body, v_message_created_at
      from public.messages m
      where m.id = p_message_id
        and m.chat_id = p_chat_id
        and m.sender_id = p_reported_user_id;
    if not found then
      raise exception 'reported_message_not_owned_by_user';
    end if;
  end if;

  if (
    select count(*)
    from public.reports r
    where r.reporter_id = v_reporter_id
      and r.created_at > now() - interval '1 hour'
  ) >= 20 then
    raise exception 'report_rate_limited';
  end if;

  insert into public.reports (
    reporter_id,
    reported_user_id,
    chat_id,
    message_id,
    reason,
    details,
    target_type,
    priority,
    reporter_id_snapshot,
    reported_user_id_snapshot,
    reporter_name_snapshot,
    reported_user_name_snapshot,
    message_body_snapshot,
    message_created_at_snapshot
  ) values (
    v_reporter_id,
    p_reported_user_id,
    p_chat_id,
    p_message_id,
    p_reason,
    nullif(trim(p_details), ''),
    case when p_message_id is null then 'user' else 'message' end,
    case when p_reason = 'child_safety' then 'child_safety' else 'standard' end,
    v_reporter_id,
    p_reported_user_id,
    v_reporter_name,
    v_reported_name,
    v_message_body,
    v_message_created_at
  ) returning id into v_report_id;

  return v_report_id;
end;
$$;

revoke all on function public.submit_report(text, uuid, uuid, uuid, text)
  from public;
grant execute on function public.submit_report(text, uuid, uuid, uuid, text)
  to authenticated;

create or replace function public.moderate_report(
  p_report_id uuid,
  p_action text,
  p_notes text default null
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_report public.reports%rowtype;
  v_request_role text := nullif(
    current_setting('request.jwt.claim.role', true),
    ''
  );
  v_actor text := coalesce(v_request_role, current_user);
begin
  if v_request_role is not null and v_request_role <> 'service_role' then
    raise exception 'moderator_forbidden';
  end if;
  if p_action not in (
    'start_review',
    'dismiss',
    'escalate',
    'remove_content',
    'suspend_account',
    'restore_account',
    'note'
  ) then
    raise exception 'invalid_moderation_action';
  end if;
  if p_action <> 'start_review' and nullif(trim(p_notes), '') is null then
    raise exception 'moderation_notes_required';
  end if;
  if p_notes is not null and length(p_notes) > 4000 then
    raise exception 'moderation_notes_too_long';
  end if;

  select * into v_report
    from public.reports r
    where r.id = p_report_id
    for update;
  if not found then
    raise exception 'report_not_found';
  end if;

  case p_action
    when 'start_review' then
      update public.reports
      set status = 'in_review'
      where id = p_report_id;
    when 'dismiss' then
      update public.reports
      set status = 'dismissed',
          resolved_at = now(),
          retention_until = now() + interval '180 days'
      where id = p_report_id;
    when 'escalate' then
      update public.reports
      set status = 'in_review',
          priority = case
            when priority = 'child_safety' then priority
            else 'urgent'
          end
      where id = p_report_id;
    when 'remove_content' then
      if v_report.message_id is null then
        raise exception 'report_has_no_live_message';
      end if;
      delete from public.messages where id = v_report.message_id;
      update public.reports
      set status = 'actioned',
          resolved_at = now(),
          retention_until = now() + interval '180 days'
      where id = p_report_id;
    when 'suspend_account' then
      if v_report.reported_user_id_snapshot is null then
        raise exception 'report_has_no_target_user';
      end if;
      insert into public.account_enforcements (
        user_id, source_report_id, reason
      ) values (
        v_report.reported_user_id_snapshot,
        p_report_id,
        trim(p_notes)
      )
      on conflict (user_id) do update
        set source_report_id = excluded.source_report_id,
            reason = excluded.reason,
            updated_at = now();
      update public.reports
      set status = 'actioned',
          resolved_at = now(),
          retention_until = now() + interval '180 days'
      where id = p_report_id;
    when 'restore_account' then
      if v_report.reported_user_id_snapshot is null then
        raise exception 'report_has_no_target_user';
      end if;
      delete from public.account_enforcements
      where user_id = v_report.reported_user_id_snapshot;
    when 'note' then
      null;
  end case;

  insert into public.moderation_actions (
    report_id,
    action,
    actor,
    notes,
    target_user_id_snapshot,
    message_id_snapshot
  ) values (
    p_report_id,
    p_action,
    v_actor,
    nullif(trim(p_notes), ''),
    v_report.reported_user_id_snapshot,
    v_report.message_id
  );
end;
$$;

revoke all on function public.moderate_report(uuid, text, text) from public;
grant execute on function public.moderate_report(uuid, text, text)
  to service_role;

create or replace function public.purge_expired_moderation_evidence()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count integer;
  v_request_role text := nullif(
    current_setting('request.jwt.claim.role', true),
    ''
  );
begin
  if v_request_role is not null and v_request_role <> 'service_role' then
    raise exception 'moderator_forbidden';
  end if;

  with expired as (
    select id
    from public.reports
    where retention_until <= now()
      and evidence_purged_at is null
      and status in ('actioned', 'dismissed')
  ), scrub_actions as (
    update public.moderation_actions a
    set notes = null,
        target_user_id_snapshot = null,
        message_id_snapshot = null
    from expired e
    where a.report_id = e.id
  )
  update public.reports r
  set reporter_id = null,
      reported_user_id = null,
      chat_id = null,
      message_id = null,
      details = null,
      reporter_id_snapshot = null,
      reported_user_id_snapshot = null,
      reporter_name_snapshot = null,
      reported_user_name_snapshot = null,
      message_body_snapshot = null,
      message_created_at_snapshot = null,
      evidence_purged_at = now()
  from expired e
  where r.id = e.id;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.purge_expired_moderation_evidence() from public;
grant execute on function public.purge_expired_moderation_evidence()
  to service_role;

create or replace view public.moderation_report_queue
with (security_invoker = false)
as
select
  r.id,
  r.created_at,
  r.priority,
  r.status,
  r.target_type,
  r.reason,
  r.details,
  r.reporter_id_snapshot,
  r.reporter_name_snapshot,
  r.reported_user_id_snapshot,
  r.reported_user_name_snapshot,
  r.chat_id,
  r.message_id,
  r.message_body_snapshot,
  r.message_created_at_snapshot,
  r.retention_until,
  e.suspended_at,
  now() - r.created_at as queue_age
from public.reports r
left join public.account_enforcements e
  on e.user_id = r.reported_user_id_snapshot
where r.status in ('pending', 'in_review');

revoke all on table public.moderation_report_queue
  from public, anon, authenticated;
grant select on table public.moderation_report_queue to service_role;

-- Suspension is enforced at the final database boundaries for the launch
-- operations that create conversations or user-generated chat content.
drop policy if exists messages_insert_sender on public.messages;
create policy messages_insert_sender on public.messages
  for insert to authenticated with check (
    auth.uid() = sender_id
    and public.is_account_active(auth.uid())
    and public.is_chat_member(chat_id)
    and not public.is_blocked_in_chat(chat_id)
  );

drop policy if exists messages_update_sender on public.messages;
create policy messages_update_sender on public.messages
  for update to authenticated
  using (
    auth.uid() = sender_id
    and public.is_account_active(auth.uid())
  )
  with check (
    auth.uid() = sender_id
    and public.is_account_active(auth.uid())
  );

create or replace function public.create_invite(
  my_learning_language text
) returns table (token text, expires_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_token text;
  v_row public.invites%rowtype;
begin
  if v_uid is null then
    raise exception 'not_signed_in';
  end if;
  if not public.is_account_active(v_uid) then
    raise exception 'account_suspended';
  end if;
  if my_learning_language is null or length(my_learning_language) <> 2 then
    raise exception 'invalid_language';
  end if;
  for attempt in 1..5 loop
    v_token := public._random_invite_token();
    begin
      insert into public.invites (
        token, inviter_user_id, inviter_learning_language
      ) values (
        v_token, v_uid, my_learning_language
      ) returning * into v_row;
      return query select v_row.token, v_row.expires_at;
      return;
    exception when unique_violation then
      continue;
    end;
  end loop;
  raise exception 'token_collision';
end;
$$;

create or replace function public.claim_invite(
  invite_token text,
  my_learning_language text
) returns table (chat_id uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.invites%rowtype;
  v_chat_id uuid;
begin
  if v_uid is null then
    raise exception 'not_signed_in';
  end if;
  if not public.is_account_active(v_uid) then
    raise exception 'account_suspended';
  end if;
  if my_learning_language is null or length(my_learning_language) <> 2 then
    raise exception 'invalid_language';
  end if;
  select * into v_row from public.invites i
    where i.token = invite_token for update;
  if not found then
    raise exception 'invite_not_found';
  end if;
  if not public.is_account_active(v_row.inviter_user_id) then
    raise exception 'inviter_unavailable';
  end if;
  if v_row.used_at is not null then
    raise exception 'invite_already_claimed';
  end if;
  if v_row.expires_at < now() then
    raise exception 'invite_expired';
  end if;
  if v_row.inviter_user_id = v_uid then
    raise exception 'invite_self_claim';
  end if;

  insert into public.chats default values returning id into v_chat_id;
  insert into public.chat_members (chat_id, user_id, learning_language)
    values (v_chat_id, v_uid, my_learning_language);
  insert into public.chat_members (chat_id, user_id, learning_language)
    values (v_chat_id, v_row.inviter_user_id, v_row.inviter_learning_language);

  update public.invites i
    set used_at = now(),
        used_by_user_id = v_uid,
        resulting_chat_id = v_chat_id
    where i.token = invite_token;

  return query select v_chat_id;
end;
$$;

revoke all on function public.create_invite(text) from public;
revoke all on function public.claim_invite(text, text) from public;
grant execute on function public.create_invite(text) to authenticated;
grant execute on function public.claim_invite(text, text) to authenticated;

drop policy if exists typing_broadcast_insert_member on realtime.messages;
create policy typing_broadcast_insert_member
on realtime.messages
for insert
to authenticated
with check (
  realtime.messages.extension = 'broadcast'
  and public.is_account_active(auth.uid())
  and public.is_typing_topic_member((select realtime.topic()))
);

comment on table public.reports is
  'Private abuse reports. Evidence is retained for 180 days after resolution unless subject to legal hold.';
comment on table public.moderation_actions is
  'Append-only audit history for operator review and enforcement decisions.';
comment on table public.account_enforcements is
  'Current account suspensions enforced by database authorization boundaries.';
