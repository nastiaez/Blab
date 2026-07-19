-- Cache both viewer-facing lanes required by the final L-15 display matrix.
-- Existing rows predate interface_text and cannot be upgraded faithfully.
delete from public.message_translations;

alter table public.message_translations
  add column interface_text text not null,
  add constraint message_translations_interface_text_check
    check (btrim(interface_text) <> '');

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
  v_body text;
  v_created_at timestamptz;
  v_deleted_at timestamptz;
  v_target_lang text;
  v_interface_lang text;
  v_cutoff_at timestamptz;
  v_source_hash text;
  v_characters integer;
  v_cached public.message_translations%rowtype;
  v_usage public.translation_usage%rowtype;
  v_retry_after integer;
begin
  if v_uid is null or not public.is_account_active(v_uid) then
    return jsonb_build_object('status', 'forbidden');
  end if;

  select
    m.body,
    m.created_at,
    m.deleted_at,
    cm.learning_language,
    cm.translation_cutoff_at,
    p.interface_language
  into
    v_body,
    v_created_at,
    v_deleted_at,
    v_target_lang,
    v_cutoff_at,
    v_interface_lang
  from public.messages m
  join public.chat_members cm
    on cm.chat_id = m.chat_id
   and cm.user_id = v_uid
  join public.profiles p on p.id = v_uid
  where m.id = p_message_id;

  if not found or v_deleted_at is not null then
    return jsonb_build_object('status', 'forbidden');
  end if;
  if v_cutoff_at is not null and v_created_at < v_cutoff_at then
    return jsonb_build_object('status', 'not_eligible');
  end if;

  select * into v_cached
  from public.message_translations mt
  where mt.message_id = p_message_id
    and mt.target_lang = v_target_lang
    and mt.interface_lang = v_interface_lang;

  if found then
    return jsonb_build_object(
      'status', 'cached',
      'mode', v_cached.aid_mode,
      'translation', v_cached.translation_text,
      'interfaceText', v_cached.interface_text,
      'sourceLang', v_cached.source_lang,
      'interfaceLang', v_cached.interface_lang,
      'explanation', v_cached.explanation,
      'confidence', v_cached.confidence,
      'tokens', v_cached.tokens
    );
  end if;

  v_body := btrim(v_body);
  v_characters := char_length(v_body);
  if v_characters = 0 or v_characters > 2000 then
    return jsonb_build_object('status', 'not_eligible');
  end if;

  insert into public.translation_usage (
    user_id,
    minute_started_at,
    minute_requests,
    day_started_at,
    day_requests,
    day_characters,
    updated_at
  ) values (
    v_uid,
    v_minute,
    0,
    v_day,
    0,
    0,
    v_now
  ) on conflict (user_id) do nothing;

  select * into v_usage
  from public.translation_usage
  where user_id = v_uid
  for update;

  if v_usage.minute_started_at <> v_minute then
    v_usage.minute_started_at := v_minute;
    v_usage.minute_requests := 0;
  end if;
  if v_usage.day_started_at <> v_day then
    v_usage.day_started_at := v_day;
    v_usage.day_requests := 0;
    v_usage.day_characters := 0;
  end if;

  if v_usage.minute_requests >= 60 then
    v_retry_after := greatest(
      1,
      ceil(extract(epoch from (
        v_minute + interval '1 minute' - v_now
      )))::integer
    );
    return jsonb_build_object(
      'status', 'rate_limited',
      'retryAfterSeconds', v_retry_after
    );
  end if;
  if v_usage.day_requests >= 200
    or v_usage.day_characters + v_characters > 100000 then
    v_retry_after := greatest(
      1,
      ceil(extract(epoch from (
        ((v_day + 1)::timestamp at time zone 'utc') - v_now
      )))::integer
    );
    return jsonb_build_object(
      'status', 'rate_limited',
      'retryAfterSeconds', v_retry_after
    );
  end if;

  update public.translation_usage
  set minute_started_at = v_usage.minute_started_at,
      minute_requests = v_usage.minute_requests + 1,
      day_started_at = v_usage.day_started_at,
      day_requests = v_usage.day_requests + 1,
      day_characters = v_usage.day_characters + v_characters,
      updated_at = v_now
  where user_id = v_uid;

  v_source_hash := encode(
    digest(convert_to(v_body, 'UTF8'), 'sha256'),
    'hex'
  );
  return jsonb_build_object(
    'status', 'ready',
    'messageId', p_message_id,
    'text', v_body,
    'sourceLang', 'auto',
    'targetLang', v_target_lang,
    'interfaceLang', v_interface_lang,
    'sourceHash', v_source_hash
  );
end;
$$;

drop function if exists public.complete_message_translation(
  uuid, uuid, text, text, text, text, text, text, text, text, jsonb
);

create function public.complete_message_translation(
  p_message_id uuid,
  p_requester_id uuid,
  p_target_lang text,
  p_interface_lang text,
  p_source_hash text,
  p_translation_text text,
  p_interface_text text,
  p_source_lang text,
  p_aid_mode text,
  p_explanation text,
  p_confidence text,
  p_tokens jsonb
) returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_body text;
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  if p_target_lang not in (
    'nl', 'en', 'fr', 'de', 'hi', 'it', 'pt', 'es', 'ta', 'tr', 'uk'
  ) or p_source_lang not in (
    'nl', 'en', 'fr', 'de', 'hi', 'it', 'pt', 'es', 'ta', 'tr', 'uk',
    'other'
  ) or p_interface_lang not in ('en', 'uk', 'de', 'es')
    or p_aid_mode not in ('translation', 'correction', 'none') then
    return false;
  end if;
  if p_source_hash !~ '^[0-9a-f]{64}$'
    or btrim(p_translation_text) = ''
    or btrim(p_interface_text) = ''
    or jsonb_typeof(p_tokens) <> 'array' then
    return false;
  end if;

  select m.body into v_body
  from public.messages m
  join public.chat_members cm
    on cm.chat_id = m.chat_id
   and cm.user_id = p_requester_id
   and cm.learning_language = p_target_lang
   and (
     cm.translation_cutoff_at is null
     or m.created_at >= cm.translation_cutoff_at
   )
  join public.profiles p
    on p.id = p_requester_id
   and p.interface_language = p_interface_lang
  where m.id = p_message_id
    and m.deleted_at is null
    and public.is_account_active(p_requester_id);

  if not found or encode(
    digest(convert_to(btrim(v_body), 'UTF8'), 'sha256'),
    'hex'
  ) <> p_source_hash then
    return false;
  end if;

  if p_interface_lang = p_target_lang
    and p_interface_text <> p_translation_text then
    return false;
  end if;
  if p_source_lang = p_interface_lang
    and p_source_lang <> p_target_lang
    and p_interface_text <> btrim(v_body) then
    return false;
  end if;

  if p_aid_mode = 'translation' then
    if p_source_lang = p_target_lang
      or p_explanation is not null
      or p_confidence is not null then
      return false;
    end if;
  elsif p_aid_mode = 'correction' then
    if p_source_lang <> p_target_lang
      or p_translation_text = btrim(v_body)
      or nullif(btrim(p_explanation), '') is null
      or p_confidence not in ('low', 'medium', 'high') then
      return false;
    end if;
  else
    if p_source_lang <> p_target_lang
      or p_translation_text <> btrim(v_body)
      or p_explanation is not null
      or p_confidence is not null then
      return false;
    end if;
  end if;

  insert into public.message_translations (
    message_id,
    target_lang,
    interface_lang,
    aid_mode,
    translation_text,
    interface_text,
    source_lang,
    explanation,
    confidence,
    tokens,
    source_hash
  ) values (
    p_message_id,
    p_target_lang,
    p_interface_lang,
    p_aid_mode,
    p_translation_text,
    p_interface_text,
    p_source_lang,
    p_explanation,
    p_confidence,
    p_tokens,
    p_source_hash
  )
  on conflict (message_id, target_lang, interface_lang) do update
  set aid_mode = excluded.aid_mode,
      translation_text = excluded.translation_text,
      interface_text = excluded.interface_text,
      source_lang = excluded.source_lang,
      explanation = excluded.explanation,
      confidence = excluded.confidence,
      tokens = excluded.tokens,
      source_hash = excluded.source_hash,
      created_at = now();

  return true;
end;
$$;

revoke all on function public.complete_message_translation(
  uuid, uuid, text, text, text, text, text, text, text, text, text, jsonb
) from public;
grant execute on function public.complete_message_translation(
  uuid, uuid, text, text, text, text, text, text, text, text, text, jsonb
) to service_role;
