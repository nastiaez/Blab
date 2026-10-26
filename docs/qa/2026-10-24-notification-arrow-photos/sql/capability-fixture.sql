create role anon; create role authenticated;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
create table public.profiles(id uuid primary key, active boolean not null default true);
create function public.is_account_active(v uuid) returns boolean language sql stable as $$select active from public.profiles where id=v$$;
create table public.push_device_tokens(token text primary key,user_id uuid references public.profiles(id),platform text not null,previews_enabled boolean not null default true,updated_at timestamptz default now(),last_seen_at timestamptz default now());
revoke all on public.push_device_tokens from public,anon,authenticated;
insert into public.profiles values ('11111111-1111-4111-8111-111111111111',true),('22222222-2222-4222-8222-222222222222',false);
