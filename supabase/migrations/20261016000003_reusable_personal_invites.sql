-- Reusable personal links; legacy claimed links retain their previous state.
alter table public.invites add column reusable boolean not null default false;
alter table public.invites add column revoked_at timestamptz;
-- Already shared, unclaimed links become reusable without changing their URL.
update public.invites set reusable = true where used_at is null;

create or replace function public.create_invite()
returns table(token text) language plpgsql security definer set search_path = public as $$
declare u uuid := auth.uid(); t text;
begin
  if u is null then raise exception 'not_signed_in'; end if;
  if not public.is_account_active(u) then raise exception 'account_suspended'; end if;
  perform pg_advisory_xact_lock(hashtextextended('invite-owner:' || u::text, 0));
  select i.token into t from public.invites i
    where i.inviter_user_id=u and i.reusable and i.revoked_at is null
      and (i.token like 'test-%') = (select channel='test' from public.app_distribution_policy where singleton)
    order by i.created_at desc, i.token limit 1;
  if t is null then
    t := public._random_invite_token();
    insert into public.invites(token,inviter_user_id,reusable) values(t,u,true);
  end if;
  return query select t;
end $$;

create function public.regenerate_invite(current_token text)
returns table(token text) language plpgsql security definer set search_path = public as $$
declare u uuid := auth.uid(); t text;
begin
  if u is null then raise exception 'not_signed_in'; end if;
  if not public.is_account_active(u) then raise exception 'account_suspended'; end if;
  perform pg_advisory_xact_lock(hashtextextended('invite-owner:' || u::text, 0));
  if not exists(select 1 from public.invites i where i.token=current_token and i.inviter_user_id=u) then
    raise exception 'invite_not_found';
  end if;
  -- Retry after a lost response must return the replacement, not rotate again.
  if exists(select 1 from public.invites i where i.token=current_token and i.revoked_at is not null) then
    return query select * from public.create_invite();
    return;
  end if;
  update public.invites set revoked_at=now() where inviter_user_id=u and revoked_at is null;
  t := public._random_invite_token();
  insert into public.invites(token,inviter_user_id,reusable) values(t,u,true);
  return query select t;
end $$;
revoke all on function public.regenerate_invite(text) from public, anon;
grant execute on function public.regenerate_invite(text) to authenticated;

create or replace function public.get_invite(invite_token text)
returns table(token text, inviter_user_id uuid, used_by_user_id uuid, resulting_chat_id uuid, status text)
language sql stable security definer set search_path = public as $$
  select i.token, i.inviter_user_id,
    case when i.reusable then null::uuid else i.used_by_user_id end,
    case when i.reusable then null::uuid else i.resulting_chat_id end,
    case when i.reusable or i.used_at is null then 'valid' else 'used' end
  from public.invites i where i.token=invite_token and i.revoked_at is null
    and (i.token like 'test-%') = (select channel='test' from public.app_distribution_policy where singleton)
    and public.has_distribution_access(i.inviter_user_id);
$$;

create or replace function public.claim_invite_in_namespace(invite_token text)
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

  select i.inviter_user_id into v_low from public.invites i where i.token = invite_token;
  if v_low is null then raise exception 'invite_not_found'; end if;
  perform pg_advisory_xact_lock(hashtextextended('invite-owner:' || v_low::text, 0));

  select * into v_row
  from public.invites i
  where i.token = invite_token
  for update;
  if not found then
    raise exception 'invite_not_found';
  end if;
  if v_row.revoked_at is not null then raise exception 'invite_not_found'; end if;
  if not v_row.reusable and v_row.used_at is not null then
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

  if v_row.reusable then
    -- One notification per recipient, not one per shared link or repeat visit.
    insert into public.push_notification_events (
      event_type, source_key, recipient_id, actor_id, chat_id
    ) values (
      'invite_claimed', v_row.token || ':' || v_uid::text,
      v_row.inviter_user_id, v_uid, v_chat_id
    ) on conflict (event_type, source_key, recipient_id) do nothing;
  else
  update public.invites i
  set used_at = now(),
      used_by_user_id = v_uid,
      resulting_chat_id = v_chat_id
  where i.token = invite_token;

  end if;

  return query select v_chat_id, v_is_new_connection;
end;
$$;

revoke all on function public.claim_invite_in_namespace(text) from public, anon, authenticated;
