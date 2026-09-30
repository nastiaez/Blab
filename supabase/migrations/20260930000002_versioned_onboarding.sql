-- Versioned onboarding state for the approved 2026-09-30 auth refresh.

alter table public.profiles
  add column onboarding_version integer not null default 0,
  add column onboarding_stage text not null default 'intro',
  add column name_confirmed_at timestamptz,
  add column translation_language_confirmed_at timestamptz,
  add column onboarding_completed_at timestamptz,
  add constraint profiles_onboarding_version_check
    check (onboarding_version >= 0),
  add constraint profiles_onboarding_stage_check
    check (onboarding_stage in ('intro', 'name', 'language', 'complete'));

revoke update (
  onboarding_version,
  onboarding_stage,
  name_confirmed_at,
  translation_language_confirmed_at,
  onboarding_completed_at
) on table public.profiles from authenticated, anon;

create or replace function public.acknowledge_my_onboarding(
  p_version integer
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_version < 1 then
    raise exception 'invalid_onboarding_version' using errcode = '23514';
  end if;
  if not public.is_account_active(v_uid) then
    raise exception 'account_suspended';
  end if;

  select * into v_profile
  from public.profiles
  where id = v_uid
  for update;

  if not found then
    raise exception 'profile_not_found';
  end if;
  if v_profile.onboarding_version > p_version then
    raise exception 'invalid_onboarding_version' using errcode = '23514';
  end if;

  if v_profile.onboarding_version < p_version then
    update public.profiles
    set onboarding_version = p_version,
        onboarding_stage = 'name',
        name_confirmed_at = null,
        translation_language_confirmed_at = null,
        onboarding_completed_at = null
    where id = v_uid
    returning * into v_profile;
  elsif v_profile.onboarding_stage = 'intro' then
    update public.profiles
    set onboarding_stage = 'name'
    where id = v_uid
    returning * into v_profile;
  end if;

  return jsonb_build_object(
    'version', v_profile.onboarding_version,
    'stage', v_profile.onboarding_stage
  );
end;
$$;

create or replace function public.confirm_my_onboarding_name(
  p_version integer,
  p_display_name text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_name text := btrim(p_display_name);
  v_profile public.profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if v_name is null
    or char_length(v_name) not between 1 and 50
    or v_name ~ '[[:cntrl:]]' then
    raise exception 'invalid_display_name' using errcode = '23514';
  end if;
  if not public.is_account_active(v_uid) then
    raise exception 'account_suspended';
  end if;

  select * into v_profile
  from public.profiles
  where id = v_uid
  for update;

  if not found then
    raise exception 'profile_not_found';
  end if;
  if v_profile.onboarding_version <> p_version then
    raise exception 'onboarding_version_mismatch' using errcode = '23514';
  end if;

  if v_profile.onboarding_stage = 'name' then
    update public.profiles
    set display_name = v_name,
        onboarding_stage = 'language',
        name_confirmed_at = coalesce(name_confirmed_at, clock_timestamp())
    where id = v_uid
    returning * into v_profile;
  elsif v_profile.onboarding_stage in ('language', 'complete')
    and v_profile.display_name = v_name then
    null;
  else
    raise exception 'invalid_onboarding_transition' using errcode = '23514';
  end if;

  return jsonb_build_object(
    'version', v_profile.onboarding_version,
    'stage', v_profile.onboarding_stage,
    'displayName', v_profile.display_name
  );
end;
$$;

create or replace function public.confirm_my_onboarding_language(
  p_version integer,
  p_language text
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_supported constant text[] := array[
    'nl', 'en', 'fr', 'de', 'hi', 'it', 'pt', 'es', 'ta', 'tr', 'uk'
  ];
  v_profile public.profiles%rowtype;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;
  if p_language is null or not (p_language = any(v_supported)) then
    raise exception 'unsupported_onboarding_language' using errcode = '23514';
  end if;
  if not public.is_account_active(v_uid) then
    raise exception 'account_suspended';
  end if;

  select * into v_profile
  from public.profiles
  where id = v_uid
  for update;

  if not found then
    raise exception 'profile_not_found';
  end if;
  if v_profile.onboarding_version <> p_version then
    raise exception 'onboarding_version_mismatch' using errcode = '23514';
  end if;

  if v_profile.onboarding_stage = 'language' then
    update public.profiles
    set known_languages = case
          when p_language = any(known_languages) then known_languages
          else array_append(known_languages, p_language)
        end,
        primary_known_language = p_language,
        onboarding_stage = 'complete',
        translation_language_confirmed_at = coalesce(
          translation_language_confirmed_at,
          clock_timestamp()
        ),
        onboarding_completed_at = coalesce(
          onboarding_completed_at,
          clock_timestamp()
        )
    where id = v_uid
    returning * into v_profile;
  elsif v_profile.onboarding_stage = 'complete'
    and v_profile.primary_known_language = p_language then
    null;
  else
    raise exception 'invalid_onboarding_transition' using errcode = '23514';
  end if;

  return jsonb_build_object(
    'version', v_profile.onboarding_version,
    'stage', v_profile.onboarding_stage,
    'primaryKnownLanguage', v_profile.primary_known_language,
    'knownLanguages', to_jsonb(v_profile.known_languages)
  );
end;
$$;

revoke all on function public.acknowledge_my_onboarding(integer) from public;
revoke all on function public.confirm_my_onboarding_name(integer, text) from public;
revoke all on function public.confirm_my_onboarding_language(integer, text) from public;

grant execute on function public.acknowledge_my_onboarding(integer) to authenticated;
grant execute on function public.confirm_my_onboarding_name(integer, text) to authenticated;
grant execute on function public.confirm_my_onboarding_language(integer, text) to authenticated;
