-- BLA-15: public release metadata only; only trusted operators can change it.
create table public.app_update_notices (
  channel text not null check (channel in ('test', 'public')),
  platform text not null check (platform in ('android', 'ios')),
  enabled boolean not null default false,
  latest_build integer not null default 0 check (latest_build >= 0),
  destination text not null,
  primary key (channel, platform)
);
alter table public.app_update_notices enable row level security;
revoke all on public.app_update_notices from public, anon, authenticated;
grant select on public.app_update_notices to anon, authenticated;
grant all on public.app_update_notices to service_role;
create policy "Anyone can read public release metadata"
  on public.app_update_notices for select to anon, authenticated using (true);

-- Never advertise a release before it is available to the intended audience.
insert into public.app_update_notices (channel, platform, destination) values
  ('test', 'android', 'https://appdistribution.firebase.google.com/testerapps/1:1084218779858:android:82904f8d21106e4911250b'),
  ('test', 'ios', 'https://testflight.apple.com/v1/app/6823316052'),
  ('public', 'android', 'https://play.google.com/store/apps/details?id=blab.nastia.ez'),
  ('public', 'ios', 'https://apps.apple.com/app/id6823314008');
