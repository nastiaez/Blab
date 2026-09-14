begin;

select plan(6);

select is(
  (select reading_script from public.profiles
   where id = '00000000-0000-4000-8000-00000000000a'),
  'native',
  'reading script defaults to native'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_reading_script_check'
  ),
  'reading script has a database constraint'
);

select ok(
  has_column_privilege(
    'authenticated',
    'public.profiles',
    'reading_script',
    'update'
  ),
  'authenticated users can update their reading script'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}',
  true
);
set local role authenticated;

update public.profiles
set reading_script = 'english_letters'
where id = auth.uid();

select is(
  (select reading_script from public.profiles where id = auth.uid()),
  'english_letters',
  'the owner can save English letters'
);

reset role;

select is(
  (select reading_script from public.profiles
   where id = '00000000-0000-4000-8000-00000000000b'),
  'native',
  'another account remains unchanged'
);

select throws_ok(
  $$update public.profiles
    set reading_script = 'mixed'
    where id = '00000000-0000-4000-8000-00000000000a'$$,
  '23514',
  null,
  'unsupported reading scripts are rejected'
);

select * from finish();
rollback;
