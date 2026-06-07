-- Invite tokens for the language-exchange "share invite link" flow.
-- One row per generated invite. 48 h TTL, single-use. The two RPCs
-- below own the create / claim paths so RLS can stay locked down on
-- the table itself.

create table public.invites (
  token text primary key,
  inviter_user_id uuid not null references public.profiles (id) on delete cascade,
  inviter_learning_language text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '48 hours'),
  used_at timestamptz,
  used_by_user_id uuid references public.profiles (id) on delete set null,
  resulting_chat_id uuid references public.chats (id) on delete set null
);

create index invites_inviter_idx on public.invites (inviter_user_id);

alter table public.invites enable row level security;

-- Direct table access is locked down. The RPCs below run with
-- SECURITY DEFINER and do all the validation themselves.
create policy invites_no_select on public.invites
  for select to authenticated using (false);
create policy invites_no_insert on public.invites
  for insert to authenticated with check (false);
create policy invites_no_update on public.invites
  for update to authenticated using (false);

-- Generates a 12-char URL-safe random token derived from a UUID. 48
-- bits of entropy is plenty for invites at v1 volumes; the create_invite
-- loop retries on the (vanishingly small) chance of a collision.
create or replace function public._random_invite_token()
returns text language sql volatile as $$
  select substr(replace(gen_random_uuid()::text, '-', ''), 1, 12);
$$;

-- create_invite: called by the would-be inviter from the New Chat
-- screen. Stores the inviter's desired learning language so the
-- recipient's landing screen can show "X invited you to learn Y"
-- without an extra round-trip.
create or replace function public.create_invite(
  my_learning_language text
) returns table (token text, expires_at timestamptz)
  language plpgsql security definer as $$
declare
  v_uid uuid := auth.uid();
  v_token text;
  v_row public.invites%rowtype;
begin
  if v_uid is null then
    raise exception 'not_signed_in';
  end if;
  if my_learning_language is null or length(my_learning_language) <> 2 then
    raise exception 'invalid_language';
  end if;
  for attempt in 1..5 loop
    v_token := public._random_invite_token();
    begin
      insert into public.invites (
        token, inviter_user_id, inviter_learning_language
      ) values (
        v_token, v_uid, my_learning_language
      ) returning * into v_row;
      return query select v_row.token, v_row.expires_at;
      return;
    exception when unique_violation then
      -- regenerate
      continue;
    end;
  end loop;
  raise exception 'token_collision';
end;
$$;

-- get_invite: public read-only fetch for the landing screen. Returns
-- inviter display name + learning language + state, never any other
-- user data. SECURITY DEFINER so it can read invites past the
-- table-level RLS deny.
create or replace function public.get_invite(invite_token text)
  returns table (
    token text,
    inviter_user_id uuid,
    inviter_name text,
    inviter_learning_language text,
    expires_at timestamptz,
    used_at timestamptz,
    status text
  ) language plpgsql security definer as $$
declare
  v_row public.invites%rowtype;
  v_name text;
begin
  select * into v_row from public.invites where token = invite_token;
  if not found then
    return;
  end if;
  select coalesce(p.display_name, '') into v_name
    from public.profiles p where p.id = v_row.inviter_user_id;
  return query
    select v_row.token,
           v_row.inviter_user_id,
           v_name,
           v_row.inviter_learning_language,
           v_row.expires_at,
           v_row.used_at,
           case
             when v_row.used_at is not null then 'used'
             when v_row.expires_at < now() then 'expired'
             else 'valid'
           end;
end;
$$;

-- claim_invite: the recipient's "Accept & join" call. Validates state,
-- creates the chat + two chat_members rows, and marks the invite used
-- in a single transaction so a successful claim is atomic.
create or replace function public.claim_invite(
  invite_token text,
  my_learning_language text
) returns table (chat_id uuid)
  language plpgsql security definer as $$
declare
  v_uid uuid := auth.uid();
  v_row public.invites%rowtype;
  v_chat_id uuid;
begin
  if v_uid is null then
    raise exception 'not_signed_in';
  end if;
  if my_learning_language is null or length(my_learning_language) <> 2 then
    raise exception 'invalid_language';
  end if;
  select * into v_row from public.invites
    where token = invite_token for update;
  if not found then
    raise exception 'invite_not_found';
  end if;
  if v_row.used_at is not null then
    raise exception 'invite_already_claimed';
  end if;
  if v_row.expires_at < now() then
    raise exception 'invite_expired';
  end if;
  if v_row.inviter_user_id = v_uid then
    raise exception 'invite_self_claim';
  end if;

  -- create the chat
  insert into public.chats default values returning id into v_chat_id;
  -- claimer (current user) — their own learning language
  insert into public.chat_members (chat_id, user_id, learning_language)
    values (v_chat_id, v_uid, my_learning_language);
  -- inviter — the language they declared when generating the link
  insert into public.chat_members (chat_id, user_id, learning_language)
    values (v_chat_id, v_row.inviter_user_id, v_row.inviter_learning_language);

  update public.invites
    set used_at = now(),
        used_by_user_id = v_uid,
        resulting_chat_id = v_chat_id
    where token = invite_token;

  return query select v_chat_id;
end;
$$;

grant execute on function public.create_invite(text) to authenticated;
grant execute on function public.get_invite(text) to anon, authenticated;
grant execute on function public.claim_invite(text, text) to authenticated;
