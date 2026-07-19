-- Add private writing corrections without changing exact authored messages.
-- Cross-language translations remain shared; correction/none results are
-- scoped to the requester so a partner cannot read private coaching output.

alter table public.message_translations
  add column aid_mode text not null default 'translation',
  add column explanation text,
  add column confidence text,
  add column scope_user_id uuid not null
    default '00000000-0000-0000-0000-000000000000',
  add constraint message_translations_aid_mode_check
    check (aid_mode in ('translation', 'correction', 'none')),
  add constraint message_translations_confidence_check
    check (confidence is null or confidence in ('low', 'medium', 'high'));

-- Previous same-language rows only echoed the source and cannot prove
-- whether the writing was correct. Force one fresh analysis when requested.
delete from public.message_translations
where source_lang = target_lang;

alter table public.message_translations
  drop constraint message_translations_pkey,
  add primary key (
    message_id,
    target_lang,
    interface_lang,
    scope_user_id
  );

drop index if exists public.message_translations_locale_lookup;
create index message_translations_locale_lookup
  on public.message_translations (
    message_id,
    target_lang,
    interface_lang,
    scope_user_id
  );

drop policy if exists message_translations_select
  on public.message_translations;
create policy message_translations_select on public.message_translations
  for select to authenticated using (
    exists (
      select 1
      from public.messages m
      join public.chat_members cm
        on cm.chat_id = m.chat_id
       and cm.user_id = auth.uid()
      join public.profiles p on p.id = cm.user_id
      where m.id = message_translations.message_id
        and m.deleted_at is null
        and cm.learning_language = message_translations.target_lang
        and p.interface_language = message_translations.interface_lang
        and (
          cm.translation_cutoff_at is null
          or m.created_at >= cm.translation_cutoff_at
        )
        and (
          message_translations.scope_user_id =
            '00000000-0000-0000-0000-000000000000'::uuid
          or message_translations.scope_user_id = auth.uid()
        )
        and (
          message_translations.aid_mode <> 'correction'
          or m.sender_id = auth.uid()
        )
    )
  );

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
  v_sender_id uuid;
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
    m.sender_id,
    m.created_at,
    m.deleted_at,
    cm.learning_language,
    cm.translation_cutoff_at,
    p.interface_language
  into
    v_body,
    v_sender_id,
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
    and mt.interface_lang = v_interface_lang
    and (
      mt.scope_user_id = v_uid
      or (
        mt.scope_user_id = '00000000-0000-0000-0000-000000000000'::uuid
        and mt.aid_mode = 'translation'
      )
    )
  order by (mt.scope_user_id = v_uid) desc
  limit 1;

  if found then
    return jsonb_build_object(
      'status', 'cached',
      'mode', v_cached.aid_mode,
      'translation', v_cached.translation_text,
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
  )
  on conflict (user_id) do nothing;

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
    'allowCorrection', v_sender_id = v_uid,
    'sourceHash', v_source_hash
  );
end;
$$;

drop function public.complete_message_translation(
  uuid, uuid, text, text, text, text, text, jsonb
);

create function public.complete_message_translation(
  p_message_id uuid,
  p_requester_id uuid,
  p_target_lang text,
  p_interface_lang text,
  p_source_hash text,
  p_translation_text text,
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
  v_sender_id uuid;
  v_scope_user_id uuid;
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
    or jsonb_typeof(p_tokens) <> 'array' then
    return false;
  end if;

  select m.body, m.sender_id into v_body, v_sender_id
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

  if p_aid_mode = 'translation' then
    if p_source_lang = p_target_lang
      or p_explanation is not null
      or p_confidence is not null then
      return false;
    end if;
    v_scope_user_id := '00000000-0000-0000-0000-000000000000'::uuid;
  elsif p_aid_mode = 'correction' then
    if p_source_lang <> p_target_lang
      or v_sender_id <> p_requester_id
      or p_translation_text = btrim(v_body)
      or nullif(btrim(p_explanation), '') is null
      or p_confidence not in ('low', 'medium', 'high') then
      return false;
    end if;
    v_scope_user_id := p_requester_id;
  else
    if p_source_lang <> p_target_lang
      or p_translation_text <> btrim(v_body)
      or p_tokens <> '[]'::jsonb
      or p_explanation is not null
      or p_confidence is not null then
      return false;
    end if;
    v_scope_user_id := p_requester_id;
  end if;

  insert into public.message_translations (
    message_id,
    target_lang,
    interface_lang,
    scope_user_id,
    aid_mode,
    translation_text,
    source_lang,
    explanation,
    confidence,
    tokens,
    source_hash
  ) values (
    p_message_id,
    p_target_lang,
    p_interface_lang,
    v_scope_user_id,
    p_aid_mode,
    p_translation_text,
    p_source_lang,
    p_explanation,
    p_confidence,
    p_tokens,
    p_source_hash
  )
  on conflict (
    message_id,
    target_lang,
    interface_lang,
    scope_user_id
  ) do update
  set aid_mode = excluded.aid_mode,
      translation_text = excluded.translation_text,
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
  uuid, uuid, text, text, text, text, text, text, text, text, jsonb
) from public;
grant execute on function public.complete_message_translation(
  uuid, uuid, text, text, text, text, text, text, text, text, jsonb
) to service_role;
