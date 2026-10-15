-- FR-47: each deployed backend is one namespace. Client labels never grant access.
create table public.app_distribution_policy (
  singleton boolean primary key default true check (singleton),
  channel text not null default 'public' check (channel in ('public', 'test')),
  testing_enabled boolean not null default false,
  testing_expires_at timestamptz
);
insert into public.app_distribution_policy(singleton) values (true);
alter table public.app_distribution_policy enable row level security;
revoke all on public.app_distribution_policy from public, anon, authenticated;
grant select, update on public.app_distribution_policy to service_role;

create table public.test_app_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default true,
  expires_at timestamptz
);
alter table public.test_app_members enable row level security;
revoke all on public.test_app_members from public, anon, authenticated;
grant select, insert, update, delete on public.test_app_members to service_role;

create function public.has_distribution_access(target_user_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select coalesce((select p.channel = 'public' or (
    p.testing_enabled and (p.testing_expires_at is null or p.testing_expires_at > now())
    and exists (select 1 from public.test_app_members m
      where m.user_id = target_user_id and m.enabled
      and (m.expires_at is null or m.expires_at > now()))
  ) from public.app_distribution_policy p where singleton), false);
$$;
revoke all on function public.has_distribution_access(uuid) from public;
grant execute on function public.has_distribution_access(uuid) to authenticated, service_role;

create or replace function public.is_account_active(target_user_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select target_user_id is not null
    and public.has_distribution_access(target_user_id)
    and not exists (select 1 from public.account_enforcements e where e.user_id = target_user_id);
$$;

create function public.get_app_distribution_access()
returns jsonb language sql stable security definer set search_path = public
as $$
  select jsonb_build_object('channel', p.channel,
    'status', case
      when p.channel = 'public' then 'active'
      when not p.testing_enabled or p.testing_expires_at <= now() then 'ended'
      when auth.uid() is null then 'signed_out'
      when public.is_account_active(auth.uid()) then 'active'
      else 'not_approved' end)
  from public.app_distribution_policy p where singleton;
$$;
revoke all on function public.get_app_distribution_access() from public;
grant execute on function public.get_app_distribution_access() to anon, authenticated;

-- Prefix is minted by this backend, not supplied by an untrusted client.
create or replace function public._random_invite_token()
returns text language sql volatile security definer set search_path = public, extensions
as $$
  select (case when p.channel = 'test' then 'test-' else '' end)
    || encode(gen_random_bytes(16), 'hex')
  from public.app_distribution_policy p where singleton;
$$;
revoke all on function public._random_invite_token() from public, anon, authenticated;

-- Protect reads as well as sends, including old installed clients. Self profile
-- and account deletion remain accessible so blocked people can manage accounts.
do $$
declare table_name text;
begin
  foreach table_name in array array[
    'chats', 'chat_members', 'messages', 'message_reads', 'message_reactions',
    'message_translations', 'message_prepared_packages', 'message_preparation_jobs',
    'message_readable_variants', 'message_attachments', 'chat_language_timeline'
  ] loop
    if to_regclass('public.' || table_name) is not null then
      execute format('create policy test_distribution_boundary on public.%I as restrictive for all to authenticated using (public.has_distribution_access(auth.uid())) with check (public.has_distribution_access(auth.uid()))', table_name);
    end if;
  end loop;
end $$;

create or replace function public.is_chat_member(target_chat_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select public.has_distribution_access(auth.uid()) and exists (
    select 1 from public.chat_members where chat_id = target_chat_id and user_id = auth.uid()
  );
$$;

-- Unknown/test tokens never become public invites by changing their URL.
create function public.enforce_invite_distribution_namespace()
returns trigger language plpgsql security definer set search_path = public
as $$
declare test_backend boolean;
begin
  select channel = 'test' into test_backend from public.app_distribution_policy where singleton;
  if (new.token like 'test-%') is distinct from test_backend then
    raise exception 'invite_channel_mismatch';
  end if;
  return new;
end $$;
create trigger enforce_invite_distribution_namespace before insert or update of token
  on public.invites for each row execute function public.enforce_invite_distribution_namespace();

alter function public.claim_invite(text) rename to claim_invite_in_namespace;
revoke all on function public.claim_invite_in_namespace(text) from public, anon, authenticated;
create function public.claim_invite(invite_token text)
returns table(chat_id uuid, is_new_connection boolean)
language plpgsql security definer set search_path = public
as $$
begin
  if (invite_token like 'test-%') is distinct from
    (select channel = 'test' from public.app_distribution_policy where singleton) then
    raise exception 'invite_channel_mismatch';
  end if;
  return query select * from public.claim_invite_in_namespace(invite_token);
end $$;
revoke all on function public.claim_invite(text) from public;
grant execute on function public.claim_invite(text) to authenticated;

create or replace function public.get_invite(invite_token text)
returns table(token text, inviter_user_id uuid, used_by_user_id uuid, resulting_chat_id uuid, status text)
language sql stable security definer set search_path = public
as $$
  select i.token, i.inviter_user_id, i.used_by_user_id, i.resulting_chat_id,
    case when i.used_at is null then 'valid' else 'used' end
  from public.invites i where i.token = invite_token
    and (i.token like 'test-%') = (select channel = 'test' from public.app_distribution_policy where singleton)
    and public.has_distribution_access(i.inviter_user_id);
$$;
