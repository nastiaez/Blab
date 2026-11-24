-- Minimal, network-isolated PostgreSQL contract fixture; not a full Supabase stack.
do $$begin if not exists(select 1 from pg_roles where rolname='anon') then create role anon;end if;if not exists(select 1 from pg_roles where rolname='authenticated') then create role authenticated;end if;end$$;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
grant usage on schema auth to authenticated;
create table public.profiles(id uuid primary key,display_name text default '',interface_language text default 'en',known_languages text[] not null default '{}',primary_known_language text,active boolean default true,account_deleted_at timestamptz);
create function public.is_account_active(p uuid) returns boolean language sql stable security definer set search_path=public as $$select coalesce((select active and account_deleted_at is null from profiles where id=p),false)$$;
create table public.chats(id uuid primary key,chat_kind text default 'direct');
create table public.chat_members(chat_id uuid references chats,user_id uuid references profiles,learning_language text not null,joined_at timestamptz not null default now(),practice_language_selected_at timestamptz,learning_language_revision bigint default 1,translation_cutoff_at timestamptz,mode text default 'normal',primary key(chat_id,user_id));
create table public.chat_language_timeline(chat_id uuid,user_id uuid,revision bigint check(revision>0),learning_language text,created_at timestamptz default now(),primary key(chat_id,user_id,revision),foreign key(chat_id,user_id) references chat_members);
create table public.messages(id uuid primary key,chat_id uuid,body text,created_at timestamptz default now());
create table public.message_prepared_packages(message_id uuid,chat_id uuid,viewer_id uuid,payload text);
create table public.message_preparation_jobs(message_id uuid,chat_id uuid,viewer_id uuid,payload text);
create function public.test_assert(ok boolean,message text) returns void language plpgsql as $$begin if ok is distinct from true then raise exception 'TEST FAILED: %',message;end if;end;$$;
alter table profiles enable row level security;
create policy profiles_self on profiles for all to authenticated using(id=auth.uid()) with check(id=auth.uid());
grant select on profiles,chat_members,chat_language_timeline to authenticated;
grant update(interface_language) on profiles to authenticated;
