-- Terminal conversations retain history; only an active pair is deduplicated.
alter table public.chats add column left_at timestamptz;
alter table public.chats add column left_by uuid references public.profiles(id) on delete set null;
alter table public.chat_members add column chat_left_at timestamptz;
alter table public.chat_members add column hidden_at timestamptz;
alter table public.chat_members add column history_cleared_at timestamptz;
alter table public.chats drop constraint chats_member_pair_key;
create unique index chats_active_member_pair_key on public.chats(member_low_id,member_high_id) where left_at is null;

-- Lifecycle columns cannot be modified through ordinary member preferences.
create function public.guard_chat_lifecycle_columns() returns trigger
language plpgsql set search_path=public as $$
begin
 if current_user not in ('postgres','supabase_admin','service_role') then
  if TG_TABLE_NAME='chats' then
   if new.left_at is distinct from old.left_at or new.left_by is distinct from old.left_by then raise insufficient_privilege; end if;
  elsif new.chat_left_at is distinct from old.chat_left_at
   or new.hidden_at is distinct from old.hidden_at
   or new.history_cleared_at is distinct from old.history_cleared_at then raise insufficient_privilege;
  end if;
 end if;
 return new;
end; $$;
create trigger guard_chat_lifecycle_columns before update on public.chats for each row execute function public.guard_chat_lifecycle_columns();
create trigger guard_chat_lifecycle_columns before update on public.chat_members for each row execute function public.guard_chat_lifecycle_columns();

create function public.leave_chat(p_chat_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare u uuid:=auth.uid(); c public.chats%rowtype;
begin
 if u is null or not public.is_account_active(u) or not public.is_chat_member(p_chat_id) then raise insufficient_privilege using message='chat_not_available'; end if;
 select * into strict c from public.chats where id=p_chat_id;
 -- Same lock ordering as invite claim, then fence all new reservations.
 perform pg_advisory_xact_lock(hashtextextended(c.member_low_id::text||':'||c.member_high_id::text,0));
 select * into strict c from public.chats where id=p_chat_id for update;
 if c.left_at is not null then return; end if;
 update public.chats set left_at=now(),left_by=u where id=p_chat_id;
 update public.chat_members set chat_left_at=now() where chat_id=p_chat_id;
end; $$;
revoke all on function public.leave_chat(uuid) from public,anon;
grant execute on function public.leave_chat(uuid) to authenticated;

create function public.guard_closed_chat_reservation() returns trigger
language plpgsql security definer set search_path=public as $$
declare ended timestamptz;
begin
 if TG_OP='INSERT' or new.status='processing' then
  select left_at into ended from public.chats where id=new.chat_id for share;
  if ended is not null then raise exception 'chat_left'; end if;
  if exists(select 1 from public.chat_members where chat_id=new.chat_id and user_id=new.actor_id and hidden_at is not null) then raise exception 'chat_deleted'; end if;
 end if;
 return new;
end; $$;
create trigger b_guard_closed_chat before insert or update on public.stream_message_commands for each row execute function public.guard_closed_chat_reservation();
create trigger b_guard_closed_chat before insert or update on public.stream_media_uploads for each row execute function public.guard_closed_chat_reservation();

create function public.guard_closed_chat_message() returns trigger
language plpgsql security definer set search_path=public as $$
declare ended timestamptz;
begin
 -- Server-owned Stream snapshots mirror already-authorized historical work.
 if auth.role()='service_role' and exists(select 1 from public.chat_message_transports where chat_id=new.chat_id and provider='stream') then return new; end if;
 select left_at into ended from public.chats where id=new.chat_id for share;
 if TG_OP='INSERT' and exists(select 1 from public.chat_members where chat_id=new.chat_id and user_id=new.sender_id and hidden_at is not null) then raise exception 'chat_deleted'; end if;
 if ended is not null and (TG_OP='INSERT' or new.body is distinct from old.body or (old.deleted_at is not null and new.deleted_at is null)) then raise exception 'chat_left'; end if;
 return new;
end; $$;
create trigger b_guard_closed_chat before insert or update on public.messages for each row execute function public.guard_closed_chat_message();

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

  -- A deliberately new invitation after a personal deletion starts a new
  -- conversation for both; joining an ordinary active pair still deduplicates.
  select c.id into v_chat_id from public.chats c
   where c.member_low_id=v_low and c.member_high_id=v_high and c.left_at is null;
  if v_chat_id is not null and exists(select 1 from public.chat_members cm where cm.chat_id=v_chat_id and cm.history_cleared_at is not null) then
    perform public.leave_chat(v_chat_id);
  end if;
  v_chat_id := null;

  insert into public.chats (member_low_id, member_high_id)
  values (v_low, v_high)
  on conflict (member_low_id, member_high_id) where left_at is null do nothing
  returning id into v_chat_id;

  if v_chat_id is null then
    select c.id into v_chat_id
    from public.chats c
    where c.member_low_id = v_low
      and c.member_high_id = v_high and c.left_at is null;
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
    -- Notify only a newly created conversation, including a fresh reinvite.
    if v_is_new_connection then
    insert into public.push_notification_events (
      event_type, source_key, recipient_id, actor_id, chat_id
    ) values (
      'invite_claimed', v_row.token || ':' || v_uid::text || ':' || v_chat_id::text,
      v_row.inviter_user_id, v_uid, v_chat_id
    ) on conflict (event_type, source_key, recipient_id) do nothing;
    end if;
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

create or replace view public.chat_list with (security_invoker = true) as
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
  coalesce(c.left_at, last_msg.created_at, c.created_at) as last_at,
  case when c.left_at is null then coalesce(unread.cnt, 0) else 0 end as unread_count,
  last_msg.id                             as last_message_id,
  me.translation_cutoff_at                as translation_cutoff_at,
  (me.practice_language_selected_at is null and c.left_at is null)
                                          as needs_practice_language_selection,
  prepared.translation_text               as last_practice_body,
  c.left_at as left_at,
  me.history_cleared_at as history_cleared_at
from public.chat_members me
join public.chats c on c.id = me.chat_id
join public.profiles viewer_profile on viewer_profile.id = me.user_id
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
where me.user_id = auth.uid() and me.hidden_at is null;


create function public.delete_chat(p_chat_id uuid) returns void
language plpgsql security definer set search_path=public as $$
declare u uuid:=auth.uid();
begin
 if u is null or not public.is_account_active(u) or not public.is_chat_member(p_chat_id) then raise insufficient_privilege using message='chat_not_available'; end if;
 perform id from public.chats where id=p_chat_id for share;
 update public.chat_members set hidden_at=now(),history_cleared_at=now()
 where chat_id=p_chat_id and user_id=u and hidden_at is null;
end; $$;
revoke all on function public.delete_chat(uuid) from public,anon;
grant execute on function public.delete_chat(uuid) to authenticated;

create function public.restore_chat_on_incoming_message() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 update public.chat_members set hidden_at=null where chat_id=new.chat_id
  and user_id<>new.sender_id and hidden_at is not null and new.created_at>hidden_at;
 return new;
end; $$;
create trigger restore_chat_on_incoming_message after insert on public.messages
 for each row execute function public.restore_chat_on_incoming_message();

create policy messages_after_personal_clear on public.messages as restrictive
 for select to authenticated using (not exists(
  select 1 from public.chat_members me where me.chat_id=messages.chat_id and me.user_id=auth.uid()
   and me.history_cleared_at is not null and messages.created_at<=me.history_cleared_at
 ));

-- Read/emoji indexes below are projections, never a second writable authority.
-- Read receipts remain explicit per-message (not a vendor prefix that marks
-- unseen messages). Device privacy OFF never calls the activity endpoint.
create or replace function public.authorize_stream_activity(p_chat_id uuid,p_action text,p_message_ids uuid[] default '{}',p_emoji text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_uid uuid:=auth.uid();v_ids uuid[];
begin
 if v_uid is null or not is_account_active(v_uid) or not is_chat_member(p_chat_id) then raise insufficient_privilege using message='chat_not_available'; end if;
 if not exists(select 1 from chat_message_transports where chat_id=p_chat_id and provider='stream' and migration_state='active') then raise exception 'stream_not_enabled'; end if;
 if p_action<>'read' and exists(select 1 from public.chats where id=p_chat_id and left_at is not null) then return jsonb_build_object('status','ignored'); end if;
 if p_action not in ('read','react','unreact','typing.start','typing.stop') or p_action is null or coalesce(cardinality(p_message_ids),0)>50 then raise exception 'invalid_activity'; end if;
 if p_action in ('typing.start','typing.stop') then
  if exists(select 1 from chat_members a join chat_members b on b.chat_id=a.chat_id and b.user_id<>a.user_id join blocks blocked on (blocked.blocker_id=a.user_id and blocked.blocked_id=b.user_id) or (blocked.blocker_id=b.user_id and blocked.blocked_id=a.user_id) where a.chat_id=p_chat_id and a.user_id=v_uid) then return jsonb_build_object('status','ignored'); end if;
  return jsonb_build_object('status','authorized','actorId',v_uid,'messageIds','[]'::jsonb);
 end if;
 if p_action='react' and (p_emoji is null or char_length(btrim(p_emoji)) not between 1 and 32 or p_emoji<>btrim(p_emoji)) then raise exception 'invalid_reaction'; end if;
 select coalesce(array_agg(m.id order by m.id),'{}'::uuid[]) into v_ids from messages m
 where m.id=any(p_message_ids) and m.chat_id=p_chat_id and m.deleted_at is null and (p_action<>'read' or m.sender_id<>v_uid);
 if p_action in ('react','unreact') and (cardinality(v_ids)<>1 or cardinality(p_message_ids)<>1) then raise insufficient_privilege using message='message_not_available'; end if;
 return jsonb_build_object('status','authorized','actorId',v_uid,'messageIds',to_jsonb(v_ids));
end; $$;
revoke all on function public.authorize_stream_activity(uuid,text,uuid[],text) from public,anon;
grant execute on function public.authorize_stream_activity(uuid,text,uuid[],text) to authenticated;


-- These helpers are trigger-only, never callable application RPCs.
revoke all on function public.guard_chat_lifecycle_columns() from public,anon,authenticated;
revoke all on function public.guard_closed_chat_reservation() from public,anon,authenticated;
revoke all on function public.guard_closed_chat_message() from public,anon,authenticated;
revoke all on function public.restore_chat_on_incoming_message() from public,anon,authenticated;
