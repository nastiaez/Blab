begin;
select plan(4);
select ok(exists (
  select 1 from pg_publication_tables
  where pubname = 'supabase_realtime' and schemaname = 'public'
    and tablename = 'message_translations'
), 'completed translations reach the existing open-chat subscription');
select ok((select relrowsecurity from pg_class
  where oid = 'public.message_translations'::regclass),
  'published translations retain row-level security');
select ok(not has_table_privilege('authenticated',
  'public.message_translations', 'insert'),
  'readable realtime cache does not grant client writes');
select ok(not has_table_privilege('anon',
  'public.message_translations', 'select'),
  'anonymous subscribers cannot read translations');
select * from finish();
rollback;
