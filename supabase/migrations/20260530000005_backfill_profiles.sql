-- Backfill profiles for users who signed up before the handle_new_user trigger existed.
insert into public.profiles (id, display_name)
select id, coalesce(raw_user_meta_data ->> 'name', '') from auth.users
on conflict (id) do nothing;
