begin;

select plan(13);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_display_name_check'
  ),
  'display names have a database constraint'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.update_my_display_name(text)',
    'execute'
  ),
  'authenticated users can invoke the self-update operation'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.update_my_display_name(text)',
    'execute'
  ),
  'anonymous users cannot invoke the self-update operation'
);

select ok(
  not has_column_privilege(
    'authenticated',
    'public.profiles',
    'display_name',
    'update'
  ),
  'clients cannot bypass validation with a direct name update'
);

select ok(
  not has_column_privilege(
    'authenticated',
    'public.profiles',
    'avatar_path',
    'update'
  ),
  'clients cannot write the dormant avatar path'
);

select ok(
  not has_column_privilege(
    'authenticated',
    'public.profiles',
    'interface_language',
    'update'
  ),
  'clients cannot directly update interface language'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  public.update_my_display_name('  Alice L14  '),
  'Alice L14',
  'the operation trims and returns the saved name'
);

select is(
  (select display_name from public.profiles where id = auth.uid()),
  'Alice L14',
  'the operation updates only the caller profile'
);

reset role;

select is(
  (select display_name from public.profiles where id = '00000000-0000-4000-8000-00000000000b'),
  'Bob Local',
  'another account remains unchanged'
);

set local role authenticated;

select throws_ok(
  $$select public.update_my_display_name('   ')$$,
  '23514',
  'invalid_display_name',
  'blank names are rejected'
);

select throws_ok(
  $$select public.update_my_display_name(repeat('a', 51))$$,
  '23514',
  'invalid_display_name',
  'over-limit names are rejected'
);

select throws_ok(
  $$select public.update_my_display_name(E'Alice\nAdmin')$$,
  '23514',
  'invalid_display_name',
  'control characters are rejected'
);

select is(
  public.update_my_interface_language('de'),
  'de',
  'the self-only interface-language operation persists a launch locale'
);

reset role;
select * from finish();
rollback;
