-- US-050 / FR-44. One account-wide presentation preference applies to
-- Hindi and Tamil. Native script remains the safe default.

alter table public.profiles
  add column reading_script text not null default 'native'
    constraint profiles_reading_script_check
      check (reading_script in ('native', 'english_letters'));

grant update (reading_script) on public.profiles to authenticated;
