-- BLA-22: separate from abuse/moderation reports. No translation writes.
create table public.translation_report_environment (
  singleton boolean primary key default true check (singleton),
  environment text not null check (environment in ('local','staging','production'))
);
alter table public.translation_report_environment enable row level security;
revoke all on public.translation_report_environment from public, anon, authenticated, service_role;
-- Deployment must explicitly configure this trusted singleton; fail closed otherwise.
create table public.translation_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  submission_id uuid not null,
  message_id uuid,
  chat_id uuid,
  reason text not null check (reason in ('incorrect','partial','wrong_language','failing','other')),
  note text not null check (char_length(note) <= 1000),
  environment text not null,
  original_text text not null,
  displayed_text text not null check (char_length(displayed_text) <= 12000),
  result_snapshot jsonb,
  settings_snapshot jsonb not null,
  client_metadata jsonb not null,
  created_at timestamptz not null default now(),
  status text not null default 'new' check (status in ('new','investigating','resolved','dismissed')),
  triage_note text not null default '' check (char_length(triage_note) <= 2000),
  triaged_at timestamptz,
  unique(reporter_id, submission_id)
);
create index translation_reports_inbox on public.translation_reports(status,created_at desc);
create index translation_reports_rate on public.translation_reports(reporter_id,created_at desc);
alter table public.translation_reports enable row level security;
revoke all on public.translation_reports from public, anon, authenticated, service_role;
grant select on public.translation_reports to service_role;

create function public.submit_translation_report(
  p_submission_id uuid, p_message_id uuid, p_reason text, p_note text,
  p_displayed_text text, p_target_language text, p_client_metadata jsonb default '{}'::jsonb
) returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare
  v_uid uuid := auth.uid();
  v_id uuid;
  v_message public.messages%rowtype;
  v_member public.chat_members%rowtype;
  v_profile public.profiles%rowtype;
  v_environment text;
  v_result jsonb;
begin
  if v_uid is null or auth.role() <> 'authenticated' then
    raise insufficient_privilege using message = 'authentication_required';
  end if;
  if p_submission_id is null or p_message_id is null or p_reason is null
    or p_reason not in ('incorrect','partial','wrong_language','failing','other')
    or p_note is null or char_length(p_note) > 1000
    or p_displayed_text is null or char_length(p_displayed_text) > 12000
    or p_target_language is null or char_length(p_target_language) > 16
    or p_client_metadata is null or jsonb_typeof(p_client_metadata) <> 'object'
    or octet_length(p_client_metadata::text) > 1024 then
    raise invalid_parameter_value using message = 'invalid_report';
  end if;
  -- Serialize this account's intake, including concurrent distinct submissions.
  perform pg_advisory_xact_lock(hashtextextended(v_uid::text, 220));
  select id into v_id from public.translation_reports
    where reporter_id = v_uid and submission_id = p_submission_id;
  if found then return v_id; end if;
  select * into v_message from public.messages where id = p_message_id
    and deleted_at is null;
  if not found then raise insufficient_privilege using message = 'message_unavailable'; end if;
  select * into v_member from public.chat_members
    where chat_id = v_message.chat_id and user_id = v_uid;
  if not found or not public.is_account_active(v_uid) then
    raise insufficient_privilege using message = 'message_unavailable';
  end if;
  -- SECURITY DEFINER bypasses RLS: reproduce every restrictive read gate.
  if not public.is_chat_member(v_message.chat_id)
    or (v_member.history_cleared_at is not null
      and v_message.created_at <= v_member.history_cleared_at)
    or not coalesce(public.group_history_visible(
      v_message.chat_id, v_message.created_at), false) then
    raise insufficient_privilege using message = 'message_unavailable';
  end if;
  select * into v_profile from public.profiles where id = v_uid;
  select environment into v_environment from public.translation_report_environment where singleton;
  if v_environment is null then raise exception 'report_intake_unconfigured'; end if;
  if (select count(*) from public.translation_reports where reporter_id=v_uid
      and created_at > now()-interval '1 minute') >= 5
    or (select count(*) from public.translation_reports where reporter_id=v_uid
      and created_at > now()-interval '1 day') >= 30 then
    raise exception 'report_rate_limited';
  end if;
  -- Never copy a different viewer's private prepared result or raw provider logs.
  select jsonb_build_object('translation',left(p.translation_text,12000),
    'interface_text',left(p.interface_text,12000),'source_lang',p.source_lang,
    'target_lang',p.learning_language,'primary_known_language',p.primary_known_language,
    'language_revision',p.language_revision,'source_version',p.source_version,
    'status',p.status,'error_code',p.error_code)
  into v_result from public.message_prepared_packages p
    where p.message_id=p_message_id and p.viewer_id=v_uid
      and p.learning_language=p_target_language
    order by p.language_revision desc limit 1;
  insert into public.translation_reports(reporter_id,submission_id,message_id,chat_id,
    reason,note,environment,original_text,displayed_text,result_snapshot,settings_snapshot,client_metadata)
  values(v_uid,p_submission_id,p_message_id,v_message.chat_id,p_reason,p_note,v_environment,
    left(v_message.body,12000),p_displayed_text,v_result,
    jsonb_build_object('interface_language',v_profile.interface_language,
      'primary_known_language',v_profile.primary_known_language,
      'learning_language',v_member.learning_language,'requested_target',p_target_language,
      'mode',to_jsonb(v_member)->'mode','learning_aids',to_jsonb(v_member)->'learning_aids',
      'known_languages',to_jsonb(v_profile)->'known_languages',
      'conversation_tone',to_jsonb(v_member)->'conversation_tone',
      'reading_script',to_jsonb(v_member)->'reading_script'),
    jsonb_build_object('platform',left(p_client_metadata->>'platform',32),
      'app_version',left(p_client_metadata->>'app_version',64),
      'displayed_text_origin','client_observation')) returning id into v_id;
  return v_id;
end $$;
revoke all on function public.submit_translation_report(uuid,uuid,text,text,text,text,jsonb) from public,anon;
grant execute on function public.submit_translation_report(uuid,uuid,text,text,text,text,jsonb) to authenticated;

create function public.triage_translation_report(p_id uuid,p_status text,p_note text)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message='service_role_required';
  end if;
  if p_status is null or p_status not in ('new','investigating','resolved','dismissed')
    or p_note is null or char_length(p_note)>2000 then
    raise invalid_parameter_value using message='invalid_triage';
  end if;
  update public.translation_reports set status=p_status,triage_note=p_note,triaged_at=now() where id=p_id;
  if not found then raise no_data_found using message='report_unavailable'; end if;
end $$;
revoke all on function public.triage_translation_report(uuid,text,text) from public,anon,authenticated;
grant execute on function public.triage_translation_report(uuid,text,text) to service_role;
