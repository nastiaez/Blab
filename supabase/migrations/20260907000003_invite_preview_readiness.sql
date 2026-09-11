-- US-006 / US-027: publish each viewer's prepared preview under existing RLS.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public'
      and tablename = 'message_prepared_packages'
  ) then
    alter publication supabase_realtime add table public.message_prepared_packages;
  end if;
end;
$$;
