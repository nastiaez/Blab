-- Server-owned rollout control for the refreshed onboarding/auth entry.

create table public.app_feature_flags (
  key text primary key,
  enabled boolean not null default false,
  updated_at timestamptz not null default clock_timestamp()
);

alter table public.app_feature_flags enable row level security;

revoke all on table public.app_feature_flags from public, anon, authenticated;
grant select, insert, update, delete on table public.app_feature_flags
  to service_role;

insert into public.app_feature_flags (key, enabled)
values ('onboarding_auth_refresh', false)
on conflict (key) do nothing;

create or replace function public.is_feature_enabled(
  p_key text
) returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select enabled
      from public.app_feature_flags
      where key = p_key
    ),
    false
  );
$$;

revoke all on function public.is_feature_enabled(text) from public;
grant execute on function public.is_feature_enabled(text) to anon, authenticated;
