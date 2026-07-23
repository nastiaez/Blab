-- Pre-launch waitlist signups from the loveblab.com landing page.
-- Public, unauthenticated form — insert-only, no read access from the
-- client. A basic email-shape check constraint keeps out obvious junk;
-- this is not full RFC validation, just a spam-resistance floor.

create table public.waitlist_signups (
  id uuid primary key default gen_random_uuid(),
  email text not null check (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
  created_at timestamptz not null default now()
);

create unique index waitlist_signups_email_idx on public.waitlist_signups (lower(email));

alter table public.waitlist_signups enable row level security;

create policy waitlist_signups_insert_anon on public.waitlist_signups
  for insert to anon with check (true);
create policy waitlist_signups_no_select on public.waitlist_signups
  for select to anon using (false);
create policy waitlist_signups_no_update on public.waitlist_signups
  for update to anon using (false);
create policy waitlist_signups_no_delete on public.waitlist_signups
  for delete to anon using (false);
