-- BLA-14 slice 1: private group creation, reusable invitations and joining.
-- Group messaging and management build on this authority in later slices.

alter table public.chats
  add column chat_kind text not null default 'direct'
    check (chat_kind in ('direct', 'group')),
  add column title text,
  add column owner_id uuid references public.profiles(id) on delete set null;

alter table public.chats
  add constraint chats_kind_shape_check check (
    (chat_kind = 'direct'
      -- Preserve the pre-group pair contract, including both-null legacy rows.
      -- chats_member_pair_order_check still rejects partial/reversed pairs.
      and ((member_low_id is null and member_high_id is null)
        or (member_low_id is not null and member_high_id is not null))
      and title is null
      and owner_id is null)
    or
    (chat_kind = 'group'
      and member_low_id is null
      and member_high_id is null
      and char_length(btrim(title)) between 1 and 60
      and owner_id is not null)
  );

create table public.group_invites (
  token text primary key,
  chat_id uuid not null references public.chats(id) on delete cascade,
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create unique index group_invites_active_chat_key
  on public.group_invites(chat_id)
  where revoked_at is null;

alter table public.group_invites enable row level security;
revoke all on table public.group_invites from public, anon, authenticated;

create or replace function public._random_group_invite_token()
returns text
language sql
volatile
set search_path = public, extensions
as $$
  select case when (select channel from public.app_distribution_policy where singleton) = 'test' then 'test-' else '' end
    || replace(encode(gen_random_bytes(16), 'base64'), '/', '_');
$$;
revoke all on function public._random_group_invite_token()
  from public, anon, authenticated;

create function public.create_group(group_name text)
returns table (chat_id uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_name text := btrim(group_name);
  v_chat_id uuid;
begin
  if v_uid is null then raise exception 'not_signed_in'; end if;
  if not public.is_account_active(v_uid) then raise exception 'account_suspended'; end if;
  if v_name is null or char_length(v_name) not between 1 and 60 then
    raise exception 'invalid_group_name';
  end if;

  insert into public.chats (chat_kind, title, owner_id)
  values ('group', v_name, v_uid)
  returning id into v_chat_id;

  insert into public.chat_members (
    chat_id, user_id, learning_language, practice_language_selected_at
  ) values (v_chat_id, v_uid, 'en', null);

  return query select v_chat_id;
end;
$$;

create function public.create_group_invite(p_chat_id uuid)
returns table (token text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_token text;
begin
  if v_uid is null or not public.is_account_active(v_uid) then
    raise insufficient_privilege using message = 'group_not_available';
  end if;
  perform 1 from public.chats c
  join public.chat_members me on me.chat_id = c.id and me.user_id = v_uid
  where c.id = p_chat_id and c.chat_kind = 'group' and c.left_at is null
    and me.hidden_at is null;
  if not found then raise insufficient_privilege using message = 'group_not_available'; end if;

  perform pg_advisory_xact_lock(hashtextextended('group-invite:' || p_chat_id::text, 0));
  select gi.token into v_token
  from public.group_invites gi
  where gi.chat_id = p_chat_id and gi.revoked_at is null;
  if v_token is not null then return query select v_token; return; end if;

  for attempt in 1..5 loop
    v_token := public._random_group_invite_token();
    begin
      insert into public.group_invites(token, chat_id, created_by)
      values (v_token, p_chat_id, v_uid);
      return query select v_token;
      return;
    exception when unique_violation then
      continue;
    end;
  end loop;
  raise exception 'token_collision';
end;
$$;

create function public.replace_group_invite(p_chat_id uuid)
returns table (token text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or not public.is_account_active(v_uid) then
    raise insufficient_privilege using message = 'group_not_available';
  end if;
  perform 1 from public.chats c
  where c.id = p_chat_id and c.chat_kind = 'group'
    and c.owner_id = v_uid and c.left_at is null;
  if not found then raise insufficient_privilege using message = 'owner_required'; end if;

  perform pg_advisory_xact_lock(hashtextextended('group-invite:' || p_chat_id::text, 0));
  update public.group_invites set revoked_at = now()
  where chat_id = p_chat_id and revoked_at is null;
  return query select created.token
  from public.create_group_invite(p_chat_id) created;
end;
$$;

create function public.get_group_invite(invite_token text)
returns table (
  token text,
  chat_id uuid,
  group_name text,
  member_count integer,
  status text,
  is_member boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    gi.token,
    c.id,
    c.title,
    members.member_count,
    case
      when gi.revoked_at is not null or c.left_at is not null then 'unavailable'
      when members.member_count >= 100 then 'full'
      else 'valid'
    end,
    exists (
      select 1 from public.chat_members me
      where me.chat_id = c.id and me.user_id = auth.uid()
        and me.hidden_at is null
    )
  from public.group_invites gi
  join public.chats c on c.id = gi.chat_id and c.chat_kind = 'group'
  cross join lateral (
    select count(*)::integer as member_count
    from public.chat_members cm where cm.chat_id = c.id
  ) members
  where gi.token = invite_token;
$$;

create function public.join_group(invite_token text)
returns table (chat_id uuid, already_member boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_invite public.group_invites%rowtype;
  v_chat public.chats%rowtype;
  v_count integer;
begin
  if v_uid is null then raise exception 'not_signed_in'; end if;
  if not public.is_account_active(v_uid) then raise exception 'account_suspended'; end if;

  select * into v_invite from public.group_invites gi
  where gi.token = invite_token for update;
  if not found then raise exception 'group_invite_not_found'; end if;
  if v_invite.revoked_at is not null then raise exception 'group_invite_unavailable'; end if;

  select * into v_chat from public.chats c
  where c.id = v_invite.chat_id and c.chat_kind = 'group' for update;
  if not found or v_chat.left_at is not null then raise exception 'group_invite_unavailable'; end if;

  if exists(select 1 from public.chat_members cm where cm.chat_id = v_chat.id and cm.user_id = v_uid) then
    return query select v_chat.id, true;
    return;
  end if;
  select count(*)::integer into v_count from public.chat_members cm where cm.chat_id = v_chat.id;
  if v_count >= 100 then raise exception 'group_full'; end if;

  insert into public.chat_members (
    chat_id, user_id, learning_language, practice_language_selected_at
  ) values (v_chat.id, v_uid, 'en', null);
  return query select v_chat.id, false;
end;
$$;

revoke all on function public.create_group(text) from public, anon;
revoke all on function public.create_group_invite(uuid) from public, anon;
revoke all on function public.replace_group_invite(uuid) from public, anon;
revoke all on function public.get_group_invite(text) from public;
revoke all on function public.join_group(text) from public, anon;
grant execute on function public.create_group(text) to authenticated;
grant execute on function public.create_group_invite(uuid) to authenticated;
grant execute on function public.replace_group_invite(uuid) to authenticated;
grant execute on function public.get_group_invite(text) to anon, authenticated;
grant execute on function public.join_group(text) to authenticated;

drop view if exists public.chat_list;
create view public.chat_list with (security_invoker = true) as
select
  me.user_id as viewer_id,
  me.chat_id as chat_id,
  case when c.chat_kind = 'direct' then partner.user_id end as partner_id,
  case when c.chat_kind = 'group' then c.title else partner_profile.display_name end as partner_name,
  case when c.chat_kind = 'direct' then partner_profile.avatar_path end as partner_avatar,
  me.learning_language as my_learning,
  coalesce(partner.learning_language, me.learning_language) as partner_learning,
  me.mode as my_mode,
  last_msg.body as last_body,
  coalesce(c.left_at, last_msg.created_at, c.created_at) as last_at,
  case when c.left_at is null then coalesce(unread.cnt, 0) else 0 end as unread_count,
  last_msg.id as last_message_id,
  me.translation_cutoff_at as translation_cutoff_at,
  (me.practice_language_selected_at is null and c.left_at is null)
    as needs_practice_language_selection,
  prepared.translation_text as last_practice_body,
  c.left_at as left_at,
  me.history_cleared_at as history_cleared_at,
  c.chat_kind,
  c.title as chat_title,
  c.owner_id,
  members.member_count
from public.chat_members me
join public.chats c on c.id = me.chat_id
join public.profiles viewer_profile on viewer_profile.id = me.user_id
left join lateral (
  select cm.user_id, cm.learning_language
  from public.chat_members cm
  where cm.chat_id = me.chat_id and cm.user_id <> me.user_id
  order by cm.joined_at, cm.user_id
  limit 1
) partner on c.chat_kind = 'direct'
left join public.profiles partner_profile on partner_profile.id = partner.user_id
cross join lateral (
  select count(*)::integer as member_count
  from public.chat_members cm where cm.chat_id = me.chat_id
) members
left join lateral (
  select id, body, created_at
  from public.messages m
  where m.chat_id = me.chat_id and m.deleted_at is null
    and m.created_at >= me.joined_at
  order by m.created_at desc
  limit 1
) last_msg on true
left join lateral (
  select package.translation_text
  from public.message_prepared_packages package
  join public.resolve_message_learning_era(last_msg.id, me.user_id) era
    on era.learning_language = package.learning_language
   and era.language_revision = package.language_revision
  where package.message_id = last_msg.id
    and package.viewer_id = me.user_id
    and me.practice_language_selected_at is not null
    and package.status = 'ready'
    and package.source_version = encode(extensions.digest(
      convert_to(btrim(last_msg.body), 'UTF8'), 'sha256'), 'hex')
    and package.primary_known_language = coalesce(
      viewer_profile.primary_known_language, viewer_profile.interface_language, 'en')
  limit 1
) prepared on true
left join lateral (
  select count(*)::integer as cnt
  from public.messages m
  where m.chat_id = me.chat_id
    and m.sender_id <> me.user_id
    and m.deleted_at is null
    and m.created_at >= me.joined_at
    and not exists (
      select 1 from public.message_reads r
      where r.message_id = m.id and r.user_id = me.user_id
    )
) unread on true
where me.user_id = auth.uid() and me.hidden_at is null;

grant select on table public.chat_list to authenticated;

alter publication supabase_realtime add table public.group_invites;
