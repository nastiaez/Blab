-- Give the translation provider a private, weak source-language hint for the
-- current message author. It is used only when a short utterance is genuinely
-- ambiguous after considering the authored text and same-sender context.

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
  v_author_primary_known_language text;
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

  select p.primary_known_language
    into v_author_primary_known_language
  from public.profiles p
  where p.id = v_message.sender_id;

  v_form_context := jsonb_build_object(
    'viewerName', coalesce(v_viewer_name, 'you'),
    'partnerName', coalesce(v_partner_name, 'your chat partner'),
    'messageAuthor', case when v_message.sender_id = v_job.viewer_id
      then 'viewer' else 'partner' end,
    'viewerForm', case when v_viewer_form in ('feminine', 'masculine')
      then v_viewer_form else null end,
    'partnerForm', case when v_partner_form in ('feminine', 'masculine')
      then v_partner_form else null end,
    'tone', case when v_tone = 'respectful' then 'respectful' else 'informal' end,
    'authorPrimaryKnownLanguage', case
      when v_author_primary_known_language in
        ('en','nl','fr','de','hi','it','pt','es','ta','tr','uk')
      then v_author_primary_known_language
      else null
    end
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
    'text', btrim(ctx.body),
    'sourceLang', ctx.source_lang) order by ctx.created_at, ctx.id), '[]'::jsonb)
    into v_context
  from (
    select m.id, m.sender_id, m.body, m.created_at, prior.source_lang
    from public.messages m
    left join lateral (
      select min(mt.source_lang) as source_lang
      from public.message_translations mt
      where mt.message_id = m.id
        and mt.source_lang <> 'other'
      having count(distinct mt.source_lang) = 1
    ) prior on true
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

-- The interactive browser/mobile path uses request_message_translation
-- directly, so it must receive the same source evidence as the worker path.
create or replace function public.request_message_translation(
  p_message_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_now timestamptz := clock_timestamp();
  v_minute timestamptz := date_trunc('minute', v_now);
  v_day date := (v_now at time zone 'utc')::date;
  v_chat_id uuid;
  v_sender_id uuid;
  v_body text;
  v_created_at timestamptz;
  v_deleted_at timestamptz;
  v_mode text;
  v_learning_lang text;
  v_language_revision bigint;
  v_era_started_at timestamptz;
  v_primary_known text;
  v_known_langs text[];
  v_interface_lang_fallback text;
  v_target_lang text;
  v_interface_lang text;
  v_source_hash text;
  v_known_source text;
  v_context jsonb := '[]'::jsonb;
  v_characters integer;
  v_cached public.message_translations%rowtype;
  v_usage public.translation_usage%rowtype;
  v_retry_after integer;
  v_viewer_name text;
  v_viewer_form text;
  v_partner_name text;
  v_partner_form text;
  v_tone text;
  v_author_primary_known_language text;
  v_form_context jsonb;
begin
  if v_uid is null or not public.is_account_active(v_uid) then
    return jsonb_build_object('status', 'forbidden');
  end if;

  select m.chat_id, m.sender_id, m.body, m.created_at, m.deleted_at,
         cm.mode, cm.partner_grammatical_form, cm.conversation_tone,
         p.primary_known_language, p.known_languages, p.interface_language,
         p.display_name, p.grammatical_form
    into v_chat_id, v_sender_id, v_body, v_created_at, v_deleted_at,
         v_mode, v_partner_form, v_tone,
         v_primary_known, v_known_langs, v_interface_lang_fallback,
         v_viewer_name, v_viewer_form
  from public.messages m
  join public.chat_members cm
    on cm.chat_id = m.chat_id and cm.user_id = v_uid
  join public.profiles p on p.id = v_uid
  where m.id = p_message_id;

  if not found or v_deleted_at is not null then
    return jsonb_build_object('status', 'forbidden');
  end if;

  select era.learning_language, era.language_revision, era.started_at
    into v_learning_lang, v_language_revision, v_era_started_at
  from public.resolve_message_learning_era(p_message_id, v_uid) era;
  if not found then
    return jsonb_build_object('status', 'forbidden');
  end if;

  select p.display_name, coalesce(p.grammatical_form, v_partner_form)
    into v_partner_name, v_partner_form
  from public.chat_members cm
  join public.profiles p on p.id = cm.user_id
  where cm.chat_id = v_chat_id and cm.user_id <> v_uid
  limit 1;

  select p.primary_known_language
    into v_author_primary_known_language
  from public.profiles p
  where p.id = v_sender_id;

  v_form_context := jsonb_build_object(
    'viewerName', coalesce(v_viewer_name, 'you'),
    'partnerName', coalesce(v_partner_name, 'your chat partner'),
    'messageAuthor', case when v_sender_id = v_uid then 'viewer' else 'partner' end,
    'viewerForm', case when v_viewer_form in ('feminine', 'masculine') then v_viewer_form else null end,
    'partnerForm', case when v_partner_form in ('feminine', 'masculine') then v_partner_form else null end,
    'tone', case when v_tone = 'respectful' then 'respectful' else 'informal' end,
    'authorPrimaryKnownLanguage', case
      when v_author_primary_known_language in
        ('en','nl','fr','de','hi','it','pt','es','ta','tr','uk')
      then v_author_primary_known_language
      else null
    end
  );

  v_target_lang := case when v_mode = 'practice'
    then v_learning_lang else coalesce(v_primary_known, v_interface_lang_fallback) end;
  v_interface_lang := coalesce(v_primary_known, v_interface_lang_fallback);

  if v_mode = 'normal' and btrim(v_body) <> '' then
    select mt.source_lang into v_known_source
    from public.message_translations mt
    where mt.message_id = p_message_id
      and mt.source_lang is not null
      and mt.source_lang = any(coalesce(v_known_langs, '{}'::text[]))
    limit 1;
    if v_known_source is not null then
      return jsonb_build_object(
        'status', 'no_aid_needed', 'mode', 'none',
        'translation', btrim(v_body), 'interfaceText', btrim(v_body),
        'sourceLang', v_known_source, 'interfaceLang', v_interface_lang,
        'tokens', '[]'::jsonb, 'formAlternatives', null,
        'languageRevision', v_language_revision
      );
    end if;
  end if;

  select * into v_cached from public.message_translations mt
  where mt.message_id = p_message_id and mt.target_lang = v_target_lang
    and mt.interface_lang = v_interface_lang;
  if found then
    return jsonb_build_object(
      'status', 'cached', 'mode', v_cached.aid_mode,
      'translation', v_cached.translation_text, 'interfaceText', v_cached.interface_text,
      'sourceLang', v_cached.source_lang, 'interfaceLang', v_cached.interface_lang,
      'explanation', v_cached.explanation, 'confidence', v_cached.confidence,
      'tokens', v_cached.tokens, 'formAlternatives', v_cached.form_alternatives,
      'languageRevision', v_language_revision
    );
  end if;

  v_body := btrim(v_body);
  v_characters := char_length(v_body);
  if v_characters = 0 or v_characters > 2000 then
    return jsonb_build_object('status', 'not_eligible');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'speaker', case when ctx.sender_id = v_uid then 'viewer' else 'partner' end,
    'text', btrim(ctx.body),
    'sourceLang', ctx.source_lang) order by ctx.created_at, ctx.id), '[]'::jsonb)
    into v_context
  from (
    select m.id, m.sender_id, m.body, m.created_at, prior.source_lang
    from public.messages m
    left join lateral (
      select min(mt.source_lang) as source_lang
      from public.message_translations mt
      where mt.message_id = m.id and mt.source_lang <> 'other'
      having count(distinct mt.source_lang) = 1
    ) prior on true
    where m.chat_id = v_chat_id and m.deleted_at is null and m.created_at < v_created_at
      and btrim(m.body) <> '' and m.body ~ '[[:alnum:]]'
      and (v_era_started_at is null or m.created_at >= v_era_started_at)
    order by m.created_at desc, m.id desc limit 8
  ) ctx;

  insert into public.translation_usage (user_id, minute_started_at, minute_requests,
    day_started_at, day_requests, day_characters, updated_at)
  values (v_uid, v_minute, 0, v_day, 0, 0, v_now) on conflict (user_id) do nothing;
  select * into v_usage from public.translation_usage where user_id = v_uid for update;
  if v_usage.minute_started_at <> v_minute then v_usage.minute_started_at := v_minute; v_usage.minute_requests := 0; end if;
  if v_usage.day_started_at <> v_day then v_usage.day_started_at := v_day; v_usage.day_requests := 0; v_usage.day_characters := 0; end if;
  if v_usage.minute_requests >= 60 then
    v_retry_after := greatest(1, ceil(extract(epoch from (v_minute + interval '1 minute' - v_now)))::integer);
    return jsonb_build_object('status', 'rate_limited', 'retryAfterSeconds', v_retry_after);
  end if;
  if v_usage.day_requests >= 200 or v_usage.day_characters + v_characters > 100000 then
    v_retry_after := greatest(1, ceil(extract(epoch from (((v_day + 1)::timestamp at time zone 'utc') - v_now)))::integer);
    return jsonb_build_object('status', 'rate_limited', 'retryAfterSeconds', v_retry_after);
  end if;
  update public.translation_usage set minute_started_at = v_usage.minute_started_at,
    minute_requests = v_usage.minute_requests + 1, day_started_at = v_usage.day_started_at,
    day_requests = v_usage.day_requests + 1, day_characters = v_usage.day_characters + v_characters,
    updated_at = v_now where user_id = v_uid;

  v_source_hash := encode(digest(convert_to(v_body, 'UTF8'), 'sha256'), 'hex');
  return jsonb_build_object(
    'status', 'ready', 'messageId', p_message_id, 'text', v_body,
    'context', v_context, 'formContext', v_form_context, 'sourceLang', 'auto',
    'targetLang', v_target_lang, 'interfaceLang', v_interface_lang,
    'sourceHash', v_source_hash, 'languageRevision', v_language_revision
  );
end;
$$;

revoke all on function public.request_message_translation(uuid) from public;
grant execute on function public.request_message_translation(uuid) to authenticated;
