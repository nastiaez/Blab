begin;

create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;

select plan(8);

select has_table(
  'public',
  'app_feature_flags',
  'rollout flags have a server-owned table'
);
select has_function(
  'public',
  'is_feature_enabled',
  array['text'],
  'clients read rollout state through one function'
);
select ok(
  has_function_privilege(
    'anon',
    'public.is_feature_enabled(text)',
    'execute'
  ),
  'signed-out clients can resolve the rollout'
);
select ok(
  has_function_privilege(
    'authenticated',
    'public.is_feature_enabled(text)',
    'execute'
  ),
  'signed-in clients can resolve the rollout'
);
select ok(
  not has_table_privilege('anon', 'public.app_feature_flags', 'select'),
  'anonymous clients cannot enumerate rollout rows'
);
select ok(
  not has_table_privilege('authenticated', 'public.app_feature_flags', 'update'),
  'authenticated clients cannot change rollout state'
);
select ok(
  has_table_privilege('service_role', 'public.app_feature_flags', 'update'),
  'service-role automation can remotely change rollout state'
);

update public.app_feature_flags
set enabled = false
where key = 'onboarding_auth_refresh';

select is(
  public.is_feature_enabled('onboarding_auth_refresh'),
  false,
  'the production-safe default keeps the legacy route enabled'
);

select * from finish();
rollback;
