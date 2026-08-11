-- Modes + known languages. See docs/superpowers/specs/2026-08-11-modes-known-languages-design.md.

alter table public.profiles
  add column known_languages text[] not null default '{}',
  add column primary_known_language text;

alter table public.chat_members
  add column mode text not null default 'practice'
    check (mode in ('normal', 'practice'));

grant update (known_languages, primary_known_language)
  on table public.profiles to authenticated;
grant update (mode) on table public.chat_members to authenticated;

drop view if exists public.chat_list;
create view public.chat_list with (security_invoker = true) as
select
  me.user_id                              as viewer_id,
  me.chat_id                              as chat_id,
  partner.user_id                         as partner_id,
  partner_profile.display_name            as partner_name,
  partner_profile.avatar_path             as partner_avatar,
  me.learning_language                    as my_learning,
  partner.learning_language               as partner_learning,
  me.mode                                 as my_mode,
  last_msg.body                           as last_body,
  last_msg.created_at                     as last_at,
  coalesce(unread.cnt, 0)                 as unread_count,
  last_msg.id                             as last_message_id,
  me.translation_cutoff_at                as translation_cutoff_at
from public.chat_members me
join public.chat_members partner
  on partner.chat_id = me.chat_id and partner.user_id <> me.user_id
join public.profiles partner_profile
  on partner_profile.id = partner.user_id
left join lateral (
  select id, body, created_at
  from public.messages m
  where m.chat_id = me.chat_id and m.deleted_at is null
  order by m.created_at desc
  limit 1
) last_msg on true
left join lateral (
  select count(*)::int as cnt
  from public.messages m
  where m.chat_id = me.chat_id
    and m.sender_id <> me.user_id
    and m.deleted_at is null
    and not exists (
      select 1 from public.message_reads r
      where r.message_id = m.id and r.user_id = me.user_id
    )
) unread on true
where me.user_id = auth.uid();

grant select on table public.chat_list to authenticated;

-- Practice mode always targets the chat's learning language (unchanged from
-- today). Normal mode targets the reader's primary known language instead.
-- The "interface" slot (second lane, shown only when practice mode is
-- expanded) always targets primary known language too, replacing
-- interface_language as a translation target everywhere.
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
  v_primary_known text;
  v_interface_lang_fallback text;
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
    cm.mode,
    p.primary_known_language,
    p.interface_language
  into
    v_chat_id,
    v_sender_id,
    v_body,
    v_created_at,
    v_deleted_at,
    v_learning_lang,
    v_cutoff_at,
    v_mode,
    v_primary_known,
    v_interface_lang_fallback
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

  -- Primary known language may be unset (onboarding for it is deferred);
  -- fall back to interface_language so a target always exists.
  v_target_lang := case when v_mode = 'practice'
    then v_learning_lang
    else coalesce(v_primary_known, v_interface_lang_fallback)
  end;
  v_interface_lang := coalesce(v_primary_known, v_interface_lang_fallback);

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
    user_id, minute_started_at, minute_requests,
    day_started_at, day_requests, day_characters, updated_at
  ) values (
    v_uid, v_minute, 0, v_day, 0, 0, v_now
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
    v_retry_after := greatest(1, ceil(extract(epoch from (
      v_minute + interval '1 minute' - v_now
    )))::integer);
    return jsonb_build_object('status', 'rate_limited', 'retryAfterSeconds', v_retry_after);
  end if;
  if v_usage.day_requests >= 200
    or v_usage.day_characters + v_characters > 100000 then
    v_retry_after := greatest(1, ceil(extract(epoch from (
      ((v_day + 1)::timestamp at time zone 'utc') - v_now
    )))::integer);
    return jsonb_build_object('status', 'rate_limited', 'retryAfterSeconds', v_retry_after);
  end if;

  update public.translation_usage
  set minute_started_at = v_usage.minute_started_at,
      minute_requests = v_usage.minute_requests + 1,
      day_started_at = v_usage.day_started_at,
      day_requests = v_usage.day_requests + 1,
      day_characters = v_usage.day_characters + v_characters,
      updated_at = v_now
  where user_id = v_uid;

  v_source_hash := encode(digest(convert_to(v_body, 'UTF8'), 'sha256'), 'hex');
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
grant execute on function public.request_message_translation(uuid) to authenticated;
