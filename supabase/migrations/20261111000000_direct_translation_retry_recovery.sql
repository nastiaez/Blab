-- BLA-47: recover failed direct translations through durable leased work.
create or replace function public.request_message_translation_variant_direct(
  p_message_id uuid, p_target_lang text default null, p_force_refresh boolean default false
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
  v_package public.message_prepared_packages%rowtype;
  v_usage public.translation_usage%rowtype;
  v_retry_after integer;
  v_viewer_name text;
  v_viewer_form text;
  v_partner_name text;
  v_partner_form text;
  v_tone text;
  v_author_primary_known_language text;
  v_form_context jsonb;
  v_attempt public.message_translation_attempts%rowtype;
  v_attempt_id uuid;
  v_pending boolean;
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

  -- The visible device mode may lead its asynchronous persisted preference.
  -- Only the two server-derived, historical/current authorized lanes exist.
  if p_target_lang is not null then
    if p_target_lang not in (v_learning_lang, v_interface_lang) then
      return jsonb_build_object('status', 'forbidden');
    end if;
    v_target_lang := p_target_lang;
    v_mode := case when p_target_lang=v_learning_lang then 'practice' else 'normal' end;
  end if;
  v_source_hash := encode(digest(convert_to(btrim(v_body), 'UTF8'), 'sha256'), 'hex');
  -- Serialize admission, not generation. All checks happen before quota usage.
  perform pg_advisory_xact_lock(hashtextextended(
    p_message_id::text || v_uid::text || v_interface_lang, 0));
  select * into v_attempt from public.message_translation_attempts
  where message_id=p_message_id and viewer_id=v_uid
    and target_lang=v_target_lang and interface_lang=v_interface_lang
    and source_hash=v_source_hash and language_revision=v_language_revision;
  v_pending := coalesce((v_attempt.status='processing' and v_attempt.started_at > clock_timestamp()-interval '45 seconds')
    or exists(select 1 from public.message_preparation_jobs j
      where j.message_id=p_message_id and j.viewer_id=v_uid
        and j.learning_language=v_learning_lang and j.primary_known_language=v_interface_lang
        and j.language_revision=v_language_revision and j.source_version=v_source_hash
        and j.status in ('queued','processing')),false);
  if p_force_refresh and v_pending then
    return jsonb_build_object('status','pending');
  end if;
  -- Retry never deletes an accepted result; cached output wins below.

  if v_mode = 'normal' and btrim(v_body) <> '' then
    select mt.source_lang into v_known_source
    from public.message_translations mt
    where mt.message_id = p_message_id
      and mt.source_lang is not null
      and mt.source_lang = any(coalesce(v_known_langs, '{}'::text[]) || array[v_interface_lang])
    limit 1;
    if v_known_source is not null then
      return jsonb_build_object(
        'status', 'no_aid_needed', 'mode', 'none',
        'translation', btrim(v_body), 'interfaceText', btrim(v_body),
        'sourceLang', v_known_source, 'interfaceLang', v_interface_lang, 'targetLang', v_target_lang,
        'tokens', '[]'::jsonb, 'formAlternatives', null,
        'languageRevision', v_language_revision
      );
    end if;
  end if;

  -- Durable generation prepares both learning and known-language outputs.
  -- Resolve the requested lane from the exact viewer/era package, not only
  -- the legacy cache row keyed by learning language.
  select * into v_package from public.message_prepared_packages k
    where k.message_id=p_message_id and k.viewer_id=v_uid
      and k.learning_language=v_learning_lang and k.primary_known_language=v_interface_lang
      and k.language_revision=v_language_revision and k.source_version=v_source_hash
      and k.status='ready';
  if found then
    return jsonb_build_object('status','cached','mode',v_package.aid_mode,
      'translation',case when v_target_lang=v_learning_lang then v_package.translation_text else v_package.interface_text end,
      'interfaceText',v_package.interface_text,'sourceLang',v_package.source_lang,
      'interfaceLang',v_interface_lang,'targetLang',v_target_lang,
      'tokens',case when v_target_lang=v_learning_lang then v_package.tokens else '[]'::jsonb end,
      'explanation',v_package.explanation,'confidence',v_package.confidence,
      'formAlternatives',case when v_target_lang=v_learning_lang then v_package.form_alternatives
        else case when v_package.form_alternatives ? 'blabGenerationEnvelope'
          then jsonb_build_object('blabGenerationEnvelope',v_package.form_alternatives->'blabGenerationEnvelope') else null end end,
      'languageRevision',v_language_revision);
  end if;

  select * into v_cached from public.message_translations mt
  where mt.message_id = p_message_id and mt.target_lang = v_target_lang
    and mt.interface_lang = v_interface_lang;
  if found then
    return jsonb_build_object(
      'status', 'cached', 'mode', v_cached.aid_mode,
      'translation', v_cached.translation_text, 'interfaceText', v_cached.interface_text,
      'sourceLang', v_cached.source_lang, 'interfaceLang', v_cached.interface_lang, 'targetLang', v_target_lang,
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

  if v_pending then
    return jsonb_build_object('status','pending');
  end if;

  -- A cache miss is not authorization to repeat exhausted work. Source edits,
  -- language eras and viewers have independent keys. Only explicit Retry bypasses.
  if not p_force_refresh and (v_attempt.id is not null or exists(
    select 1 from public.message_preparation_jobs j
    where j.message_id=p_message_id and j.viewer_id=v_uid
      and j.learning_language=v_learning_lang and j.primary_known_language=v_interface_lang
      and j.language_revision=v_language_revision and j.source_version=v_source_hash
      and j.status='failed'
  )) then
    return jsonb_build_object('status','failed');
  end if;

  -- A completed job without this requested cache lane is not active work.
  -- Do not silently retranslate its accepted companion lane or charge a no-op.
  if p_force_refresh and exists(select 1 from public.message_preparation_jobs j
    where j.message_id=p_message_id and j.viewer_id=v_uid
      and j.learning_language=v_learning_lang and j.primary_known_language=v_interface_lang
      and j.language_revision=v_language_revision and j.source_version=v_source_hash
      and j.status='ready') then
    return jsonb_build_object('status','failed');
  end if;

  v_context := public.translation_recent_context(
    p_message_id, v_uid, v_era_started_at
  );

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

  -- Explicit direct-chat recovery uses the same leased worker as initial delivery.
  -- Admission and quota reservation above remain viewer/era scoped and atomic.
  if p_force_refresh then
    insert into public.message_preparation_jobs(message_id,chat_id,viewer_id,
      learning_language,primary_known_language,language_revision,source_version)
    values(p_message_id,v_chat_id,v_uid,v_learning_lang,v_interface_lang,
      v_language_revision,v_source_hash)
    on conflict(message_id,viewer_id,learning_language,primary_known_language,
      language_revision,source_version) do update
      set status='queued',attempts=0,available_at=clock_timestamp(),last_error=null
      where message_preparation_jobs.status='failed';
    return jsonb_build_object('status','pending');
  end if;

  v_source_hash := encode(digest(convert_to(v_body, 'UTF8'), 'sha256'), 'hex');
  insert into public.message_translation_attempts(
    message_id,viewer_id,target_lang,interface_lang,source_hash,language_revision,status,started_at)
  values(p_message_id,v_uid,v_target_lang,v_interface_lang,v_source_hash,v_language_revision,'processing',clock_timestamp())
  on conflict(message_id,viewer_id,target_lang,interface_lang,source_hash,language_revision)
  do update set id=gen_random_uuid(),status='processing',started_at=excluded.started_at
  returning id into v_attempt_id;
  return jsonb_build_object(
    'attemptId',v_attempt_id,
    'status', 'ready', 'messageId', p_message_id, 'text', v_body,
    'context', v_context, 'formContext', v_form_context, 'sourceLang', 'auto',
    'targetLang', v_target_lang, 'interfaceLang', v_interface_lang,
    'sourceHash', v_source_hash, 'languageRevision', v_language_revision
  );
end;
$$;

revoke all on function public.request_message_translation_variant_direct(uuid,text,boolean) from public,anon,authenticated;
