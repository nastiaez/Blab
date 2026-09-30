begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(27);

select has_column('public', 'profiles', 'onboarding_version', 'profiles store an onboarding version');
select has_column('public', 'profiles', 'onboarding_stage', 'profiles store an onboarding stage');
select has_column('public', 'profiles', 'name_confirmed_at', 'profiles store name confirmation time');
select has_column('public', 'profiles', 'translation_language_confirmed_at', 'profiles store language confirmation time');
select has_column('public', 'profiles', 'onboarding_completed_at', 'profiles store completion time');

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_onboarding_stage_check'
  ),
  'onboarding stages are constrained'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.acknowledge_my_onboarding(integer)',
    'execute'
  ),
  'authenticated users can acknowledge onboarding'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.confirm_my_onboarding_name(integer,text)',
    'execute'
  ),
  'authenticated users can confirm their name'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.confirm_my_onboarding_language(integer,text)',
    'execute'
  ),
  'authenticated users can confirm their translation language'
);
select ok(
  not has_function_privilege(
    'anon',
    'public.confirm_my_onboarding_language(integer,text)',
    'execute'
  ),
  'anonymous users cannot advance onboarding'
);
select ok(
  not has_column_privilege(
    'authenticated',
    'public.profiles',
    'onboarding_stage',
    'update'
  ),
  'clients cannot bypass onboarding with direct stage updates'
);

select is(
  (select onboarding_version from public.profiles where id = '00000000-0000-4000-8000-00000000000a'),
  0,
  'existing profiles migrate at version zero'
);
select is(
  (select onboarding_stage from public.profiles where id = '00000000-0000-4000-8000-00000000000a'),
  'intro',
  'existing profiles migrate to intro without inferred completion'
);

update public.profiles
set known_languages = array['uk', 'de'],
    primary_known_language = 'uk'
where id = '00000000-0000-4000-8000-00000000000a';

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  (public.acknowledge_my_onboarding(1) ->> 'stage'),
  'name',
  'acknowledging the current onboarding advances intro to name'
);
select is(
  (public.acknowledge_my_onboarding(1) ->> 'stage'),
  'name',
  'acknowledgement is idempotent'
);
select throws_ok(
  $$select public.confirm_my_onboarding_name(1, '   ')$$,
  '23514',
  'invalid_display_name',
  'blank names are rejected by the onboarding operation'
);
select is(
  (public.confirm_my_onboarding_name(1, '  Alice Onboarded  ') ->> 'stage'),
  'language',
  'confirming a valid name advances to language'
);
select is(
  (select display_name from public.profiles where id = auth.uid()),
  'Alice Onboarded',
  'name confirmation trims and saves the caller name'
);
select is(
  (public.confirm_my_onboarding_name(1, 'Alice Onboarded') ->> 'stage'),
  'language',
  'name confirmation is idempotent after a network retry'
);
select throws_ok(
  $$select public.confirm_my_onboarding_language(1, 'xx')$$,
  '23514',
  'unsupported_onboarding_language',
  'unsupported translation languages are rejected'
);
select is(
  (public.confirm_my_onboarding_language(1, 'es') ->> 'stage'),
  'complete',
  'confirming a supported language completes onboarding'
);
select is(
  (select primary_known_language from public.profiles where id = auth.uid()),
  'es',
  'the confirmed choice becomes the primary translation language'
);
select is(
  (select known_languages from public.profiles where id = auth.uid()),
  array['uk', 'de', 'es']::text[],
  'language confirmation preserves existing known languages and appends the choice'
);
select is(
  (public.confirm_my_onboarding_language(1, 'es') ->> 'stage'),
  'complete',
  'language confirmation is idempotent after a network retry'
);
select throws_ok(
  $$select public.acknowledge_my_onboarding(0)$$,
  '23514',
  'invalid_onboarding_version',
  'clients cannot regress the onboarding version'
);

reset role;

select is(
  (select display_name from public.profiles where id = '00000000-0000-4000-8000-00000000000b'),
  'Bob Local',
  'another account remains unchanged'
);
select is(
  (select onboarding_stage from public.profiles where id = '00000000-0000-4000-8000-00000000000b'),
  'intro',
  'another account onboarding stage remains unchanged'
);

select * from finish();
rollback;
