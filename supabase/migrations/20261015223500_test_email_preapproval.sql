-- FR-47: operator-approved, verified email access for invited test users.
create table public.test_app_invited_emails (
  email text primary key check (email = lower(btrim(email)) and position('@' in email) > 1),
  enabled boolean not null default true,
  expires_at timestamptz
);
alter table public.test_app_invited_emails enable row level security;
revoke all on public.test_app_invited_emails from public, anon, authenticated;
grant select, insert, update, delete on public.test_app_invited_emails to service_role;

create or replace function public.has_distribution_access(target_user_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select coalesce((select p.channel = 'public' or (
    p.testing_enabled and (p.testing_expires_at is null or p.testing_expires_at > now())
    and coalesce(
      -- Explicit per-account denial or expiry takes precedence over email approval.
      (select m.enabled and (m.expires_at is null or m.expires_at > now())
       from public.test_app_members m where m.user_id = target_user_id),
      exists (select 1 from auth.users u
        join public.test_app_invited_emails i on i.email = lower(btrim(u.email))
        where u.id = target_user_id and u.email_confirmed_at is not null
          and i.enabled and (i.expires_at is null or i.expires_at > now()))
    )
  ) from public.app_distribution_policy p where singleton), false);
$$;
revoke all on function public.has_distribution_access(uuid) from public;
grant execute on function public.has_distribution_access(uuid) to authenticated, service_role;
