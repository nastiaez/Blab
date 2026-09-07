-- Waitlist email capture for the web landing page.
--
-- Reconstructed on 2026-08-12 from the production schema: this migration was
-- applied directly to the remote project on 2026-07-23 and never existed in
-- this repo, which blocked every later push. Written back verbatim (idempotent
-- throughout) so local and remote migration history agree again. Production
-- already has all of it — applying this file there is a no-op.

create table if not exists public.waitlist_signups (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  created_at timestamptz not null default now(),
  constraint waitlist_signups_email_check
    check (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

create unique index if not exists waitlist_signups_email_idx
  on public.waitlist_signups (lower(email));

alter table public.waitlist_signups enable row level security;

-- Anonymous visitors may add themselves and do nothing else: no reading the
-- list back, no editing, no deleting.
drop policy if exists waitlist_signups_insert_anon on public.waitlist_signups;
create policy waitlist_signups_insert_anon
  on public.waitlist_signups for insert to anon with check (true);

drop policy if exists waitlist_signups_no_select on public.waitlist_signups;
create policy waitlist_signups_no_select
  on public.waitlist_signups for select to anon using (false);

drop policy if exists waitlist_signups_no_update on public.waitlist_signups;
create policy waitlist_signups_no_update
  on public.waitlist_signups for update to anon using (false);

drop policy if exists waitlist_signups_no_delete on public.waitlist_signups;
create policy waitlist_signups_no_delete
  on public.waitlist_signups for delete to anon using (false);

grant all on table public.waitlist_signups to anon;
grant all on table public.waitlist_signups to authenticated;
grant all on table public.waitlist_signups to service_role;
