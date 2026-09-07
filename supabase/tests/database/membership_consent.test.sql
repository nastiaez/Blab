begin;

select plan(17);

select ok(
  to_regprocedure('public.pair_with_email(text,text,text)') is null,
  'development pair_with_email RPC is absent'
);

select ok(
  not has_table_privilege('authenticated', 'public.chats', 'INSERT'),
  'authenticated clients cannot insert chats directly'
);

select ok(
  not has_table_privilege('anon', 'public.chats', 'INSERT'),
  'anonymous clients cannot insert chats directly'
);

select ok(
  not has_table_privilege('authenticated', 'public.chat_members', 'INSERT'),
  'authenticated clients cannot insert chat memberships directly'
);

select ok(
  not has_table_privilege('anon', 'public.chat_members', 'INSERT'),
  'anonymous clients cannot insert chat memberships directly'
);

select ok(
  not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'chats'
      and policyname = 'chats_insert_self'
  ),
  'direct chat insert policy is absent'
);

select ok(
  not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'chat_members'
      and policyname = 'chat_members_insert_self'
  ),
  'direct self-membership insert policy is absent'
);

select ok(
  to_regprocedure('public.claim_invite(text)') is not null,
  'connection-only claim_invite RPC remains available'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.claim_invite(text)',
    'EXECUTE'
  ),
  'authenticated users can execute claim_invite'
);

select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'chats'
      and column_name = 'member_low_id'
  ),
  'chats stores the lower canonical participant id'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.chats'::regclass
      and conname = 'chats_member_pair_key'
      and contype = 'u'
  ),
  'canonical participant pairs have a database unique constraint'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.consolidate_duplicate_pair_chats()',
    'EXECUTE'
  ),
  'clients cannot execute the duplicate consolidation operation'
);

select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'chat_members'
      and column_name = 'translation_cutoff_at'
  ),
  'memberships persist a viewer-specific translation cutoff'
);

select ok(
  exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'chat_list'
      and column_name = 'translation_cutoff_at'
  ),
  'chat list exposes the viewer translation cutoff'
);

select ok(
  not has_table_privilege('authenticated', 'public.chat_members', 'UPDATE'),
  'authenticated clients do not have table-wide membership updates'
);

select ok(
  has_column_privilege(
    'authenticated',
    'public.chat_members',
    'learning_language',
    'UPDATE'
  ),
  'authenticated clients can update their learning language'
);

select ok(
  not has_column_privilege(
    'authenticated',
    'public.chat_members',
    'translation_cutoff_at',
    'UPDATE'
  ),
  'authenticated clients cannot move the translation cutoff'
);

select * from finish();
rollback;
