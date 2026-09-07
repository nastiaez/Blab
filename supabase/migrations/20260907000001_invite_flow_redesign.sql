-- US-008 / US-025 / US-026 / US-027: invitations create a connection only.
-- A practice language is chosen privately by each participant inside the chat.

alter table public.chat_members
  add column practice_language_selected_at timestamptz;

-- Every existing membership came from the old language-first flow and is
-- therefore already configured. Only memberships created by the new claim
-- path begin with a null selection timestamp.
update public.chat_members
set practice_language_selected_at = coalesce(joined_at, now())
where practice_language_selected_at is null;

alter table public.invites
  drop column expires_at,
  drop column inviter_learning_language;

drop function if exists public.create_invite(text);
drop function if exists public.get_invite(text);
drop function if exists public.claim_invite(text, text);

create function public.create_invite()
returns table (token text)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_token text;
begin
  if v_uid is null then
    raise exception 'not_signed_in';
  end if;
  if not public.is_account_active(v_uid) then
    raise exception 'account_suspended';
  end if;

  for attempt in 1..5 loop
    v_token := public._random_invite_token();
    begin
      insert into public.invites (token, inviter_user_id)
      values (v_token, v_uid);
      return query select v_token;
      return;
    exception when unique_violation then
      continue;
    end;
  end loop;

  raise exception 'token_collision';
end;
$$;

create function public.get_invite(invite_token text)
returns table (
  token text,
  inviter_user_id uuid,
  used_by_user_id uuid,
  resulting_chat_id uuid,
  status text
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.invites%rowtype;
begin
  select * into v_row
  from public.invites i
  where i.token = invite_token;
  if not found then
    return;
  end if;

  return query
  select
    v_row.token,
    v_row.inviter_user_id,
    v_row.used_by_user_id,
    v_row.resulting_chat_id,
    case when v_row.used_at is null then 'valid' else 'used' end;
end;
$$;

create or replace function public.set_translation_cutoff_on_language_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.practice_language_selected_at is null then
    new.practice_language_selected_at := statement_timestamp();
  else
    new.practice_language_selected_at := old.practice_language_selected_at;
  end if;

  if old.learning_language is distinct from new.learning_language then
    new.translation_cutoff_at := statement_timestamp();
  else
    new.translation_cutoff_at := old.translation_cutoff_at;
  end if;
  return new;
end;
$$;

create function public.claim_invite(invite_token text)
returns table (chat_id uuid, is_new_connection boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.invites%rowtype;
  v_chat_id uuid;
  v_low uuid;
  v_high uuid;
  v_is_new_connection boolean := false;
begin
  if v_uid is null then
    raise exception 'not_signed_in';
  end if;
  if not public.is_account_active(v_uid) then
    raise exception 'account_suspended';
  end if;

  select * into v_row
  from public.invites i
  where i.token = invite_token
  for update;
  if not found then
    raise exception 'invite_not_found';
  end if;
  if v_row.used_at is not null then
    raise exception 'invite_already_claimed';
  end if;
  if v_row.inviter_user_id = v_uid then
    raise exception 'invite_self_claim';
  end if;
  if not public.is_account_active(v_row.inviter_user_id) then
    raise exception 'inviter_unavailable';
  end if;

  if v_uid::text < v_row.inviter_user_id::text then
    v_low := v_uid;
    v_high := v_row.inviter_user_id;
  else
    v_low := v_row.inviter_user_id;
    v_high := v_uid;
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended(v_low::text || ':' || v_high::text, 0)
  );

  insert into public.chats (member_low_id, member_high_id)
  values (v_low, v_high)
  on conflict (member_low_id, member_high_id) do nothing
  returning id into v_chat_id;

  if v_chat_id is null then
    select c.id into v_chat_id
    from public.chats c
    where c.member_low_id = v_low
      and c.member_high_id = v_high;
  else
    v_is_new_connection := true;
    insert into public.chat_members (
      chat_id,
      user_id,
      learning_language,
      practice_language_selected_at
    ) values
      (v_chat_id, v_uid, 'en', null),
      (v_chat_id, v_row.inviter_user_id, 'en', null);
  end if;

  update public.invites i
  set used_at = now(),
      used_by_user_id = v_uid,
      resulting_chat_id = v_chat_id
  where i.token = invite_token;

  return query select v_chat_id, v_is_new_connection;
end;
$$;

drop view if exists public.chat_list;
create view public.chat_list with (security_invoker = true) as
select
  me.user_id                              as viewer_id,
  me.chat_id                              as chat_id,
  partner.user_id                         as partner_id,
  partner_profile.display_name            as partner_name,
  partner_profile.avatar_path             as partner_avatar,
  me.learning_language                    as my_learning,
  partner.learning_language               as partner_learning,
  me.mode                                 as my_mode,
  last_msg.body                           as last_body,
  coalesce(last_msg.created_at, c.created_at) as last_at,
  coalesce(unread.cnt, 0)                 as unread_count,
  last_msg.id                             as last_message_id,
  me.translation_cutoff_at                as translation_cutoff_at,
  me.practice_language_selected_at is null
                                          as needs_practice_language_selection
from public.chat_members me
join public.chats c on c.id = me.chat_id
join public.chat_members partner
  on partner.chat_id = me.chat_id and partner.user_id <> me.user_id
join public.profiles partner_profile
  on partner_profile.id = partner.user_id
left join lateral (
  select id, body, created_at
  from public.messages m
  where m.chat_id = me.chat_id and m.deleted_at is null
  order by m.created_at desc
  limit 1
) last_msg on true
left join lateral (
  select count(*)::int as cnt
  from public.messages m
  where m.chat_id = me.chat_id
    and m.sender_id <> me.user_id
    and m.deleted_at is null
    and not exists (
      select 1 from public.message_reads r
      where r.message_id = m.id and r.user_id = me.user_id
    )
) unread on true
where me.user_id = auth.uid();

grant select on table public.chat_list to authenticated;
grant execute on function public.create_invite() to authenticated;
grant execute on function public.get_invite(text) to anon, authenticated;
grant execute on function public.claim_invite(text) to authenticated;
