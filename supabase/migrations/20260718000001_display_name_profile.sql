-- L-14: make display names a validated, server-owned profile operation.

-- Normalize legacy rows before enforcing the launch contract.
update public.profiles
set display_name = left(
  coalesce(
    nullif(btrim(regexp_replace(display_name, '[[:cntrl:]]', '', 'g')), ''),
    'User'
  ),
  50
)
where display_name <> btrim(display_name)
  or char_length(display_name) not between 1 and 50
  or display_name ~ '[[:cntrl:]]';

alter table public.profiles
  add constraint profiles_display_name_check check (
    display_name = btrim(display_name)
    and char_length(display_name) between 1 and 50
    and display_name !~ '[[:cntrl:]]'
  );

-- Social providers do not consistently use the same metadata key. Always
-- create a valid profile, then let the user choose a different name in-app.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  v_name := left(
    coalesce(
      nullif(
        btrim(
          regexp_replace(
            coalesce(new.raw_user_meta_data ->> 'name', ''),
            '[[:cntrl:]]',
            '',
            'g'
          )
        ),
        ''
      ),
      nullif(
        btrim(
          regexp_replace(
            coalesce(new.raw_user_meta_data ->> 'full_name', ''),
            '[[:cntrl:]]',
            '',
            'g'
          )
        ),
        ''
      ),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'User'
    ),
    50
  );

  insert into public.profiles (id, display_name)
  values (new.id, v_name);
  return new;
end;
$$;

-- Identity changes go through the self-only RPC below. Keep the unrelated
-- interface-language preference available to its existing client path.
revoke update on table public.profiles from authenticated;
grant update (interface_language) on table public.profiles to authenticated;

create or replace function public.update_my_display_name(p_display_name text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_name text := btrim(p_display_name);
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if not public.is_account_active(v_uid) then
    raise exception 'account_suspended';
  end if;

  if v_name is null
    or char_length(v_name) not between 1 and 50
    or v_name ~ '[[:cntrl:]]' then
    raise exception 'invalid_display_name' using errcode = '23514';
  end if;

  update public.profiles
  set display_name = v_name
  where id = v_uid;

  if not found then
    raise exception 'profile_not_found';
  end if;

  return v_name;
end;
$$;

revoke all on function public.update_my_display_name(text) from public;
grant execute on function public.update_my_display_name(text) to authenticated;
