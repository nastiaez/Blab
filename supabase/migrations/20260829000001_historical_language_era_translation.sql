-- US-044 / FR-38 / FR-39: historical messages remain attached to the
-- viewer-private learning-language era active when each message arrived.

create or replace function public.resolve_message_learning_era(
  p_message_id uuid,
  p_viewer_id uuid
) returns table (
  learning_language text,
  language_revision bigint,
  started_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select picked.learning_language, picked.revision, picked.started_at
  from public.messages m
  join public.chat_members cm
    on cm.chat_id = m.chat_id
   and cm.user_id = p_viewer_id
  cross join lateral (
    select
      coalesce(
        (
          select t.learning_language
          from public.chat_language_timeline t
          where t.chat_id = m.chat_id
            and t.user_id = p_viewer_id
            and t.created_at <= m.created_at
          order by t.created_at desc, t.revision desc
          limit 1
        ),
        (
          select t.learning_language
          from public.chat_language_timeline t
          where t.chat_id = m.chat_id
            and t.user_id = p_viewer_id
          order by t.revision asc
          limit 1
        ),
        cm.learning_language
      ) as learning_language,
      coalesce(
        (
          select t.revision
          from public.chat_language_timeline t
          where t.chat_id = m.chat_id
            and t.user_id = p_viewer_id
            and t.created_at <= m.created_at
          order by t.created_at desc, t.revision desc
          limit 1
        ),
        (
          select t.revision
          from public.chat_language_timeline t
          where t.chat_id = m.chat_id
            and t.user_id = p_viewer_id
          order by t.revision asc
          limit 1
        ),
        cm.learning_language_revision
      ) as revision,
      (
        select t.created_at
        from public.chat_language_timeline t
        where t.chat_id = m.chat_id
          and t.user_id = p_viewer_id
          and t.created_at <= m.created_at
        order by t.created_at desc, t.revision desc
        limit 1
      ) as started_at
  ) picked
  where m.id = p_message_id
    and (
      p_viewer_id = auth.uid()
      or auth.role() = 'service_role'
    );
$$;

revoke all on function public.resolve_message_learning_era(uuid, uuid)
  from public, anon;
grant execute on function public.resolve_message_learning_era(uuid, uuid)
  to authenticated, service_role;

drop policy if exists message_translations_select
  on public.message_translations;
create policy message_translations_select
  on public.message_translations
  for select to authenticated
  using (
    public.is_account_active(auth.uid())
    and exists (
      select 1
      from public.messages m
      join public.chat_members cm
        on cm.chat_id = m.chat_id
       and cm.user_id = auth.uid()
      where m.id = message_translations.message_id
        and m.deleted_at is null
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
  v_form_context := jsonb_build_object(
    'viewerName', coalesce(v_viewer_name, 'you'),
    'partnerName', coalesce(v_partner_name, 'your chat partner'),
    'messageAuthor', case when v_sender_id = v_uid then 'viewer' else 'partner' end,
    'viewerForm', case when v_viewer_form in ('feminine', 'masculine') then v_viewer_form else null end,
    'partnerForm', case when v_partner_form in ('feminine', 'masculine') then v_partner_form else null end,
    'tone', case when v_tone = 'respectful' then 'respectful' else 'informal' end
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
    'text', btrim(ctx.body)) order by ctx.created_at, ctx.id), '[]'::jsonb)
    into v_context
  from (
    select m.id, m.sender_id, m.body, m.created_at from public.messages m
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

create or replace function public.complete_message_translation(
  p_message_id uuid, p_requester_id uuid, p_target_lang text, p_interface_lang text,
  p_source_hash text, p_translation_text text, p_interface_text text, p_source_lang text,
  p_aid_mode text, p_explanation text, p_confidence text, p_tokens jsonb,
  p_form_alternatives jsonb
) returns boolean
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_body text;
  v_mode text;
  v_learning_lang text;
  v_primary_known text;
  v_expected_target text;
begin
  if auth.role() is distinct from 'service_role' then raise insufficient_privilege using message = 'service_role_required'; end if;
  if p_target_lang not in ('nl','en','fr','de','hi','it','pt','es','ta','tr','uk')
    or p_source_lang not in ('nl','en','fr','de','hi','it','pt','es','ta','tr','uk','other')
    or p_interface_lang not in ('en','uk','de','es') or p_aid_mode not in ('translation','correction','none')
    or p_source_hash !~ '^[0-9a-f]{64}$' or btrim(p_translation_text) = ''
    or btrim(p_interface_text) = '' or jsonb_typeof(p_tokens) <> 'array' then return false; end if;
  if p_form_alternatives is not null and (
    p_aid_mode <> 'translation' or jsonb_typeof(p_form_alternatives) <> 'object'
    or not (p_form_alternatives ?& array['before','feminine','masculine','after','subjectName','subjectIsViewer'])
    or jsonb_typeof(p_form_alternatives->'before') <> 'string'
    or jsonb_typeof(p_form_alternatives->'feminine') <> 'string'
    or jsonb_typeof(p_form_alternatives->'masculine') <> 'string'
    or jsonb_typeof(p_form_alternatives->'after') <> 'string'
    or jsonb_typeof(p_form_alternatives->'subjectName') <> 'string'
    or jsonb_typeof(p_form_alternatives->'subjectIsViewer') <> 'boolean'
    or btrim(p_form_alternatives->>'feminine') = ''
    or btrim(p_form_alternatives->>'masculine') = ''
    or p_form_alternatives->>'feminine' = p_form_alternatives->>'masculine'
    or (
      coalesce(p_form_alternatives->>'before','') ||
      coalesce(p_form_alternatives->>'feminine','') ||
      coalesce(p_form_alternatives->>'after','')
    ) <> p_translation_text
  ) then return false; end if;

  select m.body, cm.mode,
         coalesce(p.primary_known_language, p.interface_language)
    into v_body, v_mode, v_primary_known
  from public.messages m
  join public.chat_members cm
    on cm.chat_id = m.chat_id and cm.user_id = p_requester_id
  join public.profiles p on p.id = p_requester_id
  where m.id = p_message_id
    and m.deleted_at is null
    and public.is_account_active(p_requester_id);
  if not found then return false; end if;

  select era.learning_language into v_learning_lang
  from public.resolve_message_learning_era(p_message_id, p_requester_id) era;
  if not found then return false; end if;
  v_expected_target := case when v_mode = 'practice'
    then v_learning_lang else v_primary_known end;
  if p_target_lang <> v_expected_target or p_interface_lang <> v_primary_known then
    return false;
  end if;
  if encode(digest(convert_to(btrim(v_body),'UTF8'),'sha256'),'hex') <> p_source_hash then return false; end if;
  if p_interface_lang=p_target_lang and p_interface_text<>p_translation_text then return false; end if;
  if p_source_lang=p_interface_lang and p_source_lang<>p_target_lang and p_interface_text<>btrim(v_body) then return false; end if;
  if p_aid_mode='translation' then
    if p_source_lang=p_target_lang or p_explanation is not null or p_confidence is not null then return false; end if;
  elsif p_aid_mode='correction' then
    if p_source_lang<>p_target_lang or p_translation_text=btrim(v_body) or nullif(btrim(p_explanation),'') is null or p_confidence not in ('low','medium','high') then return false; end if;
  else
    if p_source_lang<>p_target_lang or p_translation_text<>btrim(v_body) or p_explanation is not null or p_confidence is not null then return false; end if;
  end if;
  insert into public.message_translations (message_id,target_lang,interface_lang,aid_mode,translation_text,interface_text,source_lang,explanation,confidence,tokens,source_hash,form_alternatives)
  values (p_message_id,p_target_lang,p_interface_lang,p_aid_mode,p_translation_text,p_interface_text,p_source_lang,p_explanation,p_confidence,p_tokens,p_source_hash,p_form_alternatives)
  on conflict (message_id,target_lang,interface_lang) do update set aid_mode=excluded.aid_mode, translation_text=excluded.translation_text,
    interface_text=excluded.interface_text, source_lang=excluded.source_lang, explanation=excluded.explanation,
    confidence=excluded.confidence, tokens=excluded.tokens, source_hash=excluded.source_hash,
    form_alternatives=excluded.form_alternatives, created_at=now();
  return true;
end;
$$;

revoke all on function public.complete_message_translation(uuid, uuid, text, text, text, text, text, text, text, text, text, jsonb, jsonb) from public;
grant execute on function public.complete_message_translation(uuid, uuid, text, text, text, text, text, text, text, text, text, jsonb, jsonb) to service_role;
