-- US-043 / US-044: deliver completed cache rows to the existing open-chat
-- subscription, including results that finish after the visible deadline.
-- Existing membership SELECT policy remains the authorization boundary.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'message_translations'
  ) then
    alter publication supabase_realtime add table public.message_translations;
  end if;
end;
$$;
