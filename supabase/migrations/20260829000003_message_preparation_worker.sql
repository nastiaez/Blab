-- US-044 / FR-38 / FR-41: translate delivery jobs outside the chat screen.
-- Claims are bounded and oldest-first; every viewer variant settles alone.

create or replace function public.claim_message_preparation_jobs_for_worker(
  p_limit integer default 10
) returns setof public.message_preparation_jobs
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;

  update public.message_preparation_jobs
  set status = 'queued',
      locked_at = null,
      available_at = now(),
      last_error = 'lease_expired'
  where status = 'processing'
    and locked_at < now() - interval '5 minutes';

  return query
  with picked as (
    select id
    from public.message_preparation_jobs
    where status = 'queued'
      and available_at <= now()
    order by created_at, id
    limit greatest(1, least(coalesce(p_limit, 10), 20))
    for update skip locked
  )
  update public.message_preparation_jobs j
  set status = 'processing',
      locked_at = now(),
      attempts = j.attempts + 1
  from picked
  where j.id = picked.id
  returning j.*;
end;
$$;

revoke all on function public.claim_message_preparation_jobs_for_worker(integer)
  from public, anon, authenticated;
grant execute on function public.claim_message_preparation_jobs_for_worker(integer)
  to service_role;

create or replace function public.request_message_translation_job(
  p_job_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_job public.message_preparation_jobs%rowtype;
  v_message public.messages%rowtype;
  v_era record;
  v_cached public.message_translations%rowtype;
  v_viewer_name text;
  v_viewer_form text;
  v_partner_name text;
  v_partner_form text;
  v_tone text;
  v_context jsonb := '[]'::jsonb;
  v_form_context jsonb;
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;

  select * into v_job
  from public.message_preparation_jobs
  where id = p_job_id and status = 'processing'
  for update;
  if not found then
    return jsonb_build_object('status', 'stale');
  end if;

  select * into v_message
  from public.messages
  where id = v_job.message_id and deleted_at is null;
  if not found
      or encode(digest(convert_to(btrim(v_message.body), 'UTF8'), 'sha256'), 'hex')
        <> v_job.source_version then
    return jsonb_build_object('status', 'stale');
  end if;

  select * into v_era
  from public.resolve_message_learning_era(v_job.message_id, v_job.viewer_id);
  if not found
      or v_era.learning_language <> v_job.learning_language
      or v_era.language_revision <> v_job.language_revision then
    return jsonb_build_object('status', 'stale');
  end if;

  select p.display_name, p.grammatical_form,
         cm.partner_grammatical_form, cm.conversation_tone
    into v_viewer_name, v_viewer_form, v_partner_form, v_tone
  from public.chat_members cm
  join public.profiles p on p.id = cm.user_id
  where cm.chat_id = v_job.chat_id and cm.user_id = v_job.viewer_id;
  if not found then
    return jsonb_build_object('status', 'stale');
  end if;

  select p.display_name, coalesce(p.grammatical_form, v_partner_form)
    into v_partner_name, v_partner_form
  from public.chat_members cm
  join public.profiles p on p.id = cm.user_id
  where cm.chat_id = v_job.chat_id and cm.user_id <> v_job.viewer_id
  limit 1;
  v_form_context := jsonb_build_object(
    'viewerName', coalesce(v_viewer_name, 'you'),
    'partnerName', coalesce(v_partner_name, 'your chat partner'),
    'messageAuthor', case when v_message.sender_id = v_job.viewer_id
      then 'viewer' else 'partner' end,
    'viewerForm', case when v_viewer_form in ('feminine', 'masculine')
      then v_viewer_form else null end,
    'partnerForm', case when v_partner_form in ('feminine', 'masculine')
      then v_partner_form else null end,
    'tone', case when v_tone = 'respectful' then 'respectful' else 'informal' end
  );

  select * into v_cached
  from public.message_translations mt
  where mt.message_id = v_job.message_id
    and mt.target_lang = v_job.learning_language
    and mt.interface_lang = v_job.primary_known_language;
  if found then
    insert into public.message_prepared_packages (
      message_id, chat_id, viewer_id, learning_language,
      primary_known_language, language_revision, source_version, status,
      translation_text, interface_text, source_lang, aid_mode, explanation,
      confidence, tokens, form_alternatives, error_code, resolved_at
    ) values (
      v_job.message_id, v_job.chat_id, v_job.viewer_id,
      v_job.learning_language, v_job.primary_known_language,
      v_job.language_revision, v_job.source_version, 'ready',
      v_cached.translation_text, v_cached.interface_text,
      v_cached.source_lang, v_cached.aid_mode, v_cached.explanation,
      v_cached.confidence, v_cached.tokens, v_cached.form_alternatives,
      null, now()
    )
    on conflict (
      message_id, viewer_id, learning_language, primary_known_language,
      language_revision, source_version
    ) do update set
      status = 'ready',
      translation_text = excluded.translation_text,
      interface_text = excluded.interface_text,
      source_lang = excluded.source_lang,
      aid_mode = excluded.aid_mode,
      explanation = excluded.explanation,
      confidence = excluded.confidence,
      tokens = excluded.tokens,
      form_alternatives = excluded.form_alternatives,
      error_code = null,
      resolved_at = now();
    update public.message_preparation_jobs
    set status = 'ready', locked_at = null, last_error = null
    where id = v_job.id;
    return jsonb_build_object(
      'status', 'cached',
      'translation', v_cached.translation_text,
      'interfaceText', v_cached.interface_text,
      'mode', v_cached.aid_mode,
      'sourceLang', v_cached.source_lang,
      'interfaceLang', v_cached.interface_lang,
      'explanation', v_cached.explanation,
      'confidence', v_cached.confidence,
      'tokens', v_cached.tokens,
      'formAlternatives', v_cached.form_alternatives
    );
  end if;

  if btrim(v_message.body) = '' or char_length(btrim(v_message.body)) > 2000 then
    return jsonb_build_object('status', 'not_eligible');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'speaker', case when ctx.sender_id = v_job.viewer_id then 'viewer' else 'partner' end,
    'text', btrim(ctx.body)) order by ctx.created_at, ctx.id), '[]'::jsonb)
    into v_context
  from (
    select m.id, m.sender_id, m.body, m.created_at
    from public.messages m
    where m.chat_id = v_job.chat_id
      and m.deleted_at is null
      and m.created_at < v_message.created_at
      and btrim(m.body) <> ''
      and m.body ~ '[[:alnum:]]'
      and (v_era.started_at is null or m.created_at >= v_era.started_at)
    order by m.created_at desc, m.id desc
    limit 8
  ) ctx;

  return jsonb_build_object(
    'status', 'ready',
    'jobId', v_job.id,
    'requesterId', v_job.viewer_id,
    'messageId', v_job.message_id,
    'text', btrim(v_message.body),
    'context', v_context,
    'formContext', v_form_context,
    'sourceLang', 'auto',
    'targetLang', v_job.learning_language,
    'interfaceLang', v_job.primary_known_language,
    'sourceHash', v_job.source_version
  );
end;
$$;

revoke all on function public.request_message_translation_job(uuid)
  from public, anon, authenticated;
grant execute on function public.request_message_translation_job(uuid)
  to service_role;

create or replace function public.complete_message_translation_job(
  p_job_id uuid,
  p_translation_text text,
  p_interface_text text,
  p_source_lang text,
  p_aid_mode text,
  p_explanation text,
  p_confidence text,
  p_tokens jsonb,
  p_form_alternatives jsonb
) returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_job public.message_preparation_jobs%rowtype;
  v_message public.messages%rowtype;
  v_era record;
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  select * into v_job
  from public.message_preparation_jobs
  where id = p_job_id and status = 'processing'
  for update;
  if not found then return false; end if;
  select * into v_message
  from public.messages
  where id = v_job.message_id and deleted_at is null;
  if not found
      or encode(digest(convert_to(btrim(v_message.body), 'UTF8'), 'sha256'), 'hex')
        <> v_job.source_version then return false; end if;
  select * into v_era
  from public.resolve_message_learning_era(v_job.message_id, v_job.viewer_id);
  if not found
      or v_era.learning_language <> v_job.learning_language
      or v_era.language_revision <> v_job.language_revision then return false; end if;
  if v_job.learning_language not in ('nl','en','fr','de','hi','it','pt','es','ta','tr','uk')
    or p_source_lang not in ('nl','en','fr','de','hi','it','pt','es','ta','tr','uk','other')
    or v_job.primary_known_language not in ('en','uk','de','es')
    or p_aid_mode not in ('translation','correction','none')
    or btrim(p_translation_text) = '' or btrim(p_interface_text) = ''
    or jsonb_typeof(p_tokens) <> 'array' then return false; end if;
  if p_form_alternatives is not null and (
    p_aid_mode <> 'translation' or jsonb_typeof(p_form_alternatives) <> 'object'
    or not (p_form_alternatives ?& array['before','feminine','masculine','after','subjectName','subjectIsViewer'])
    or btrim(p_form_alternatives->>'feminine') = ''
    or btrim(p_form_alternatives->>'masculine') = ''
    or p_form_alternatives->>'feminine' = p_form_alternatives->>'masculine'
    or coalesce(p_form_alternatives->>'before','') ||
       coalesce(p_form_alternatives->>'feminine','') ||
       coalesce(p_form_alternatives->>'after','') <> p_translation_text
  ) then return false; end if;
  if v_job.primary_known_language = v_job.learning_language
      and p_interface_text <> p_translation_text then return false; end if;
  if p_source_lang = v_job.primary_known_language
      and p_source_lang <> v_job.learning_language
      and p_interface_text <> btrim(v_message.body) then return false; end if;
  if p_aid_mode = 'translation' then
    if p_source_lang = v_job.learning_language
        or p_explanation is not null or p_confidence is not null then return false; end if;
  elsif p_aid_mode = 'correction' then
    if p_source_lang <> v_job.learning_language
        or p_translation_text = btrim(v_message.body)
        or nullif(btrim(p_explanation), '') is null
        or p_confidence not in ('low','medium','high') then return false; end if;
  else
    if p_source_lang <> v_job.learning_language
        or p_translation_text <> btrim(v_message.body)
        or p_explanation is not null or p_confidence is not null then return false; end if;
  end if;

  insert into public.message_translations (
    message_id, target_lang, interface_lang, aid_mode, translation_text,
    interface_text, source_lang, explanation, confidence, tokens,
    source_hash, form_alternatives
  ) values (
    v_job.message_id, v_job.learning_language, v_job.primary_known_language,
    p_aid_mode, p_translation_text, p_interface_text, p_source_lang,
    p_explanation, p_confidence, p_tokens, v_job.source_version,
    p_form_alternatives
  )
  on conflict (message_id, target_lang, interface_lang) do update set
    aid_mode = excluded.aid_mode,
    translation_text = excluded.translation_text,
    interface_text = excluded.interface_text,
    source_lang = excluded.source_lang,
    explanation = excluded.explanation,
    confidence = excluded.confidence,
    tokens = excluded.tokens,
    source_hash = excluded.source_hash,
    form_alternatives = excluded.form_alternatives,
    created_at = now();

  insert into public.message_prepared_packages (
    message_id, chat_id, viewer_id, learning_language,
    primary_known_language, language_revision, source_version, status,
    translation_text, interface_text, source_lang, aid_mode, explanation,
    confidence, tokens, form_alternatives, error_code, resolved_at
  ) values (
    v_job.message_id, v_job.chat_id, v_job.viewer_id,
    v_job.learning_language, v_job.primary_known_language,
    v_job.language_revision, v_job.source_version, 'ready',
    p_translation_text, p_interface_text, p_source_lang, p_aid_mode,
    p_explanation, p_confidence, p_tokens, p_form_alternatives, null, now()
  )
  on conflict (
    message_id, viewer_id, learning_language, primary_known_language,
    language_revision, source_version
  ) do update set
    status = 'ready',
    translation_text = excluded.translation_text,
    interface_text = excluded.interface_text,
    source_lang = excluded.source_lang,
    aid_mode = excluded.aid_mode,
    explanation = excluded.explanation,
    confidence = excluded.confidence,
    tokens = excluded.tokens,
    form_alternatives = excluded.form_alternatives,
    error_code = null,
    resolved_at = now();
  update public.message_preparation_jobs
  set status = 'ready', locked_at = null, last_error = null
  where id = v_job.id;
  return true;
end;
$$;

revoke all on function public.complete_message_translation_job(
  uuid, text, text, text, text, text, text, jsonb, jsonb
) from public, anon, authenticated;
grant execute on function public.complete_message_translation_job(
  uuid, text, text, text, text, text, text, jsonb, jsonb
) to service_role;

create or replace function public.finish_message_preparation_job(
  p_job_id uuid,
  p_outcome text,
  p_error text,
  p_delay_seconds integer default 0
) returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_job public.message_preparation_jobs%rowtype;
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  select * into v_job
  from public.message_preparation_jobs
  where id = p_job_id and status = 'processing'
  for update;
  if not found then return false; end if;
  if p_outcome = 'retry' then
    update public.message_preparation_jobs
    set status = 'queued',
        available_at = now() + make_interval(secs => greatest(1, least(p_delay_seconds, 300))),
        locked_at = null,
        last_error = left(coalesce(p_error, 'retryable'), 120)
    where id = p_job_id;
  elsif p_outcome = 'stale' then
    delete from public.message_preparation_jobs where id = p_job_id;
  elsif p_outcome in ('failed', 'ready') then
    update public.message_preparation_jobs
    set status = p_outcome,
        locked_at = null,
        last_error = case when p_outcome = 'failed'
          then left(coalesce(p_error, 'failed'), 120) else null end
    where id = p_job_id;
    if p_outcome = 'failed' then
      insert into public.message_prepared_packages (
        message_id, chat_id, viewer_id, learning_language,
        primary_known_language, language_revision, source_version,
        status, error_code, resolved_at
      ) values (
        v_job.message_id, v_job.chat_id, v_job.viewer_id,
        v_job.learning_language, v_job.primary_known_language,
        v_job.language_revision, v_job.source_version,
        'failed', left(coalesce(p_error, 'failed'), 120), now()
      )
      on conflict (
        message_id, viewer_id, learning_language, primary_known_language,
        language_revision, source_version
      ) do update set
        status = 'failed',
        error_code = excluded.error_code,
        resolved_at = now();
    end if;
  else
    return false;
  end if;
  return true;
end;
$$;

revoke all on function public.finish_message_preparation_job(uuid, text, text, integer)
  from public, anon, authenticated;
grant execute on function public.finish_message_preparation_job(uuid, text, text, integer)
  to service_role;

-- A language marker starts a new era for future messages. Work already tied
-- to an earlier message era stays queued so it can finish above that marker.
create or replace function public.set_learning_language(
  p_chat_id uuid,
  p_learning_language text
) returns bigint
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_old public.chat_members%rowtype;
  v_revision bigint;
begin
  if v_uid is null or not public.is_account_active(v_uid)
      or p_learning_language not in ('nl','en','fr','de','hi','it','pt','es','ta','tr','uk') then
    raise exception 'invalid_learning_language';
  end if;
  select * into v_old
  from public.chat_members
  where chat_id = p_chat_id and user_id = v_uid
  for update;
  if not found then raise exception 'chat_membership_not_found'; end if;
  if v_old.learning_language = p_learning_language then
    return v_old.learning_language_revision;
  end if;
  v_revision := v_old.learning_language_revision + 1;
  update public.chat_members
  set learning_language = p_learning_language,
      learning_language_revision = v_revision,
      translation_cutoff_at = statement_timestamp()
  where chat_id = p_chat_id and user_id = v_uid;
  insert into public.chat_language_timeline (
    chat_id, user_id, revision, learning_language
  ) values (p_chat_id, v_uid, v_revision, p_learning_language)
  on conflict (chat_id, user_id, revision) do nothing;
  return v_revision;
end;
$$;

revoke all on function public.set_learning_language(uuid, text)
  from public, anon;
grant execute on function public.set_learning_language(uuid, text)
  to authenticated;

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron with schema extensions;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.request_message_preparation_worker()
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_url text;
  v_service_key text;
begin
  select decrypted_secret into v_url
  from vault.decrypted_secrets
  where name = 'blab_translation_worker_url';
  select decrypted_secret into v_service_key
  from vault.decrypted_secrets
  where name = 'blab_worker_service_role_key';
  if v_url is null
      or v_url !~ '^https?://[^/]+/functions/v1/prepare-message-jobs$'
      or v_service_key is null
      or length(v_service_key) < 24 then
    raise warning 'Blab translation worker is not configured';
    return;
  end if;
  perform net.http_post(
    url := v_url,
    body := jsonb_build_object('limit', 10),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_key
    ),
    timeout_milliseconds := 5000
  );
exception when others then
  raise warning 'Blab translation worker dispatch failed: %', sqlerrm;
end;
$$;

revoke all on function private.request_message_preparation_worker()
  from public, anon, authenticated;

create or replace function private.dispatch_message_preparation_jobs()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
begin
  perform private.request_message_preparation_worker();
  return null;
end;
$$;

revoke all on function private.dispatch_message_preparation_jobs()
  from public, anon, authenticated;
drop trigger if exists dispatch_message_preparation_jobs
  on public.message_preparation_jobs;
create trigger dispatch_message_preparation_jobs
  after insert on public.message_preparation_jobs
  for each statement execute function private.dispatch_message_preparation_jobs();

do $$
declare v_job_id bigint;
begin
  select jobid into v_job_id from cron.job
  where jobname = 'blab-message-preparation-recovery';
  if v_job_id is not null then perform cron.unschedule(v_job_id); end if;
  perform cron.schedule(
    'blab-message-preparation-recovery',
    '* * * * *',
    'select private.request_message_preparation_worker()'
  );
end;
$$;
