-- US-001 / owner21696: new memberships only; legacy/history migration excluded.
begin;
alter table public.profiles add column default_learning_language text
  constraint profiles_default_learning_language_check check(default_learning_language in
    ('en','nl','fr','de','hi','it','pt','es','ta','tr','uk','da','fi','ko','mr','pl'));
revoke update(default_learning_language) on public.profiles from anon,authenticated;

create function public.confirm_my_onboarding_languages(
 p_version integer,p_learning_language text,p_known_language text
) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
 v_uid uuid:=auth.uid(); v_profile public.profiles%rowtype; v_known text;
 v_supported constant text[]:=array['en','nl','fr','de','hi','it','pt','es','ta','tr','uk','da','fi','ko','mr','pl'];
begin
 if v_uid is null then raise exception 'not_authenticated';end if;
 if not public.is_account_active(v_uid) then raise exception 'account_suspended';end if;
 if p_learning_language is null or not(p_learning_language=any(v_supported))
   or p_known_language is null or not(p_known_language=any(v_supported)) then
  raise exception 'unsupported_onboarding_language' using errcode='23514';
 end if;
 select * into v_profile from public.profiles where id=v_uid for update;
 if not found then raise exception 'profile_not_found';end if;
 if not public.is_account_active(v_uid) then raise exception 'account_suspended';end if;
 if p_version is distinct from 1 or v_profile.onboarding_version is distinct from p_version then
  raise exception 'onboarding_version_mismatch' using errcode='23514';
 end if;
 if v_profile.onboarding_stage='language' then
  v_known:=coalesce(v_profile.primary_known_language,p_known_language);
  update public.profiles set default_learning_language=coalesce(default_learning_language,p_learning_language),
   primary_known_language=v_known,
   known_languages=case when v_known=any(known_languages) then known_languages else array_append(known_languages,v_known) end,
   onboarding_stage='complete',
   translation_language_confirmed_at=coalesce(translation_language_confirmed_at,clock_timestamp()),
   onboarding_completed_at=coalesce(onboarding_completed_at,clock_timestamp())
  where id=v_uid returning * into v_profile;
 elsif v_profile.onboarding_stage='complete' and v_profile.default_learning_language is not null then
  null;
 else raise exception 'invalid_onboarding_transition' using errcode='23514';end if;
 return jsonb_build_object('version',v_profile.onboarding_version,'stage',v_profile.onboarding_stage,
  'primaryKnownLanguage',v_profile.primary_known_language,'knownLanguages',to_jsonb(v_profile.known_languages),
  'defaultLearningLanguage',v_profile.default_learning_language);
end;$$;
revoke all on function public.confirm_my_onboarding_languages(integer,text,text) from public,anon;
grant execute on function public.confirm_my_onboarding_languages(integer,text,text) to authenticated;

create function public.apply_new_membership_learning_default() returns trigger
language plpgsql security definer set search_path=public,pg_temp as $$
declare v_language text;
begin
 if new.practice_language_selected_at is not null then return new;end if;
 -- BEFORE INSERT also runs for ON CONFLICT; never reinitialize an existing row.
 if exists(select 1 from public.chat_members where chat_id=new.chat_id and user_id=new.user_id) then return new;end if;
 if not public.is_account_active(new.user_id) then return new;end if;
 select default_learning_language into v_language from public.profiles where id=new.user_id for share;
 if v_language is not null and public.is_account_active(new.user_id) then
  new.learning_language:=v_language;
  new.practice_language_selected_at:=coalesce(new.joined_at,statement_timestamp());
 end if;
 return new;
end;$$;
revoke all on function public.apply_new_membership_learning_default() from public,anon,authenticated;
create trigger apply_new_membership_learning_default before insert on public.chat_members
 for each row execute function public.apply_new_membership_learning_default();

create function public.clear_erased_learning_default() returns trigger
language plpgsql set search_path=public,pg_temp as $$
begin new.default_learning_language:=null;return new;end;$$;
revoke all on function public.clear_erased_learning_default() from public,anon,authenticated;
create trigger clear_erased_learning_default before update of account_deleted_at on public.profiles
 for each row when (old.account_deleted_at is null and new.account_deleted_at is not null)
 execute function public.clear_erased_learning_default();
commit;
