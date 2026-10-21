-- A removed member must receive a revocation hint even after membership RLS
-- excludes them from all group data. Only the recipient sees their tombstone.
grant select on public.group_departures to authenticated;
create policy group_departures_own on public.group_departures for select to authenticated
 using(user_id=auth.uid() and public.is_account_active(auth.uid()));
alter publication supabase_realtime add table public.group_departures;
