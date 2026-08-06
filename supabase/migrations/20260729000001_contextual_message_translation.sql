-- Add bounded same-chat context to translation preparation so short messages
-- with omitted subjects/pronouns can be translated naturally.
-- Existing cache rows were generated without context, so regenerate them.
delete from public.message_translations;

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
  v_target_lang text;
  v_interface_lang text;
  v_cutoff_at timestamptz;
  v_source_hash text;
  v_context jsonb := '[]'::jsonb;
  v_characters integer;
  v_cached public.message_translations%rowtype;
  v_usage public.translation_usage%rowtype;
  v_retry_after integer;
begin
  if v_uid is null or not public.is_account_active(v_uid) then
    return jsonb_build_object('status', 'forbidden');
  end if;

  select
    m.chat_id,
    m.sender_id,
    m.body,
    m.created_at,
    m.deleted_at,
    cm.learning_language,
    cm.translation_cutoff_at,
    p.interface_language
  into
    v_chat_id,
    v_sender_id,
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

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'speaker',
        case when ctx.sender_id = v_uid then 'viewer' else 'partner' end,
        'text',
        btrim(ctx.body)
      )
      order by ctx.created_at, ctx.id
    ),
    '[]'::jsonb
  )
  into v_context
  from (
    select m.id, m.sender_id, m.body, m.created_at
    from public.messages m
    where m.chat_id = v_chat_id
      and m.deleted_at is null
      and m.created_at < v_created_at
      and btrim(m.body) <> ''
      and m.body ~ '[[:alnum:]]'
      and (
        v_cutoff_at is null
        or m.created_at >= v_cutoff_at
      )
    order by m.created_at desc, m.id desc
    limit 8
  ) ctx;

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
    'context', v_context,
    'sourceLang', 'auto',
    'targetLang', v_target_lang,
    'interfaceLang', v_interface_lang,
    'sourceHash', v_source_hash
  );
end;
$$;

revoke all on function public.request_message_translation(uuid) from public;
grant execute on function public.request_message_translation(uuid)
  to authenticated;
