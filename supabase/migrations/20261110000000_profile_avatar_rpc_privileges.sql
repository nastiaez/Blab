-- BLA-39: remove Supabase default anonymous EXECUTE without changing actor access.
-- Forward-only: the previously applied profile-photo migration stays immutable.
revoke execute on function public.update_my_avatar(text, uuid) from public, anon;
