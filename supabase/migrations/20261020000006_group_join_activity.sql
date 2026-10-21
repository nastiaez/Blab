-- Topic7420 /14578: neutral, localized join activity in the paginated timeline.
alter table public.messages drop constraint messages_message_type_check;
alter table public.messages add constraint messages_message_type_check
 check(message_type in ('text','image','group_joined'));
create function public.guard_group_activity() returns trigger
language plpgsql set search_path=public as $$
begin
 if (new.message_type='group_joined' or (TG_OP='UPDATE' and old.message_type='group_joined'))
   and current_user not in ('postgres','supabase_admin','service_role') then
  raise insufficient_privilege using message='group_activity_server_only';
 end if;
 if new.message_type='group_joined' and not exists(select 1 from public.chats where id=new.chat_id and chat_kind='group') then raise insufficient_privilege; end if;
 return new;
end; $$;
create trigger a_guard_group_activity before insert or update on public.messages
 for each row execute function public.guard_group_activity();
revoke all on function public.guard_group_activity() from public,anon,authenticated;
create function public.record_group_join_activity() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if exists(select 1 from public.chats where id=new.chat_id and chat_kind='group' and left_at is null)
  and exists(select 1 from public.chat_members where chat_id=new.chat_id and user_id<>new.user_id) then
  insert into public.messages(chat_id,sender_id,body,message_type)
   values(new.chat_id,new.user_id,'','group_joined');
 end if;
 return new;
end; $$;
create trigger record_group_join_activity after insert on public.chat_members
 for each row execute function public.record_group_join_activity();
revoke all on function public.record_group_join_activity() from public,anon,authenticated;

create or replace function public.group_ai_eligible(p_message_id uuid,p_viewer_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select coalesce((select c.chat_kind='direct' or (m.message_type<>'group_joined' and c.left_at is null and exists(
  select 1 from public.chat_members cm where cm.chat_id=m.chat_id and cm.user_id=p_viewer_id
   and cm.chat_left_at is null and m.created_at>=cm.joined_at
 )) from public.messages m join public.chats c on c.id=m.chat_id where m.id=p_message_id),false);
$$;

create function public.unread_message_ids(p_chat_id uuid)
returns table(message_id uuid) language sql stable security invoker set search_path=public as $$
 select m.id from public.messages m join public.chats c on c.id=m.chat_id
 join public.chat_members me on me.chat_id=m.chat_id and me.user_id=auth.uid()
 where m.chat_id=p_chat_id and m.sender_id<>auth.uid() and m.deleted_at is null
  and m.message_type<>'group_joined' and (c.chat_kind='direct' or m.created_at>=me.joined_at)
  and not exists(select 1 from public.message_reads r where r.message_id=m.id and r.user_id=auth.uid())
 order by m.created_at,m.id;
$$;
revoke all on function public.unread_message_ids(uuid) from public,anon;
grant execute on function public.unread_message_ids(uuid) to authenticated;

create or replace function public.enqueue_message_push()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.message_type='group_joined' then return new; end if;
  if exists(select 1 from chat_message_transports where chat_id=new.chat_id
    and provider='stream' and migration_state='active') then return new; end if;
  insert into push_notification_events(event_type,source_key,recipient_id,actor_id,chat_id)
    select 'chat_message',new.id::text,member.user_id,new.sender_id,new.chat_id
    from chat_members member join chats c on c.id=member.chat_id
    where member.chat_id=new.chat_id and member.user_id<>new.sender_id
      and (c.chat_kind='direct' or (member.notifications_enabled
        and member.chat_left_at is null and c.left_at is null))
    on conflict(event_type,source_key,recipient_id) do nothing;
  return new;
end; $$;

create or replace function public.snapshot_group_message_recipients()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.message_type='group_joined' then return new; end if;
 perform 1 from public.chats c where c.id=new.chat_id and c.chat_kind='group' for share;
 if not found then return new; end if;
 insert into public.group_message_recipients(message_id,user_id)
 select new.id,cm.user_id from public.chat_members cm
 where cm.chat_id=new.chat_id and cm.user_id<>new.sender_id
 and cm.chat_left_at is null and cm.joined_at<=new.created_at;
 return new;
end; $$;

create or replace function public.restore_chat_on_incoming_message() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if new.message_type='group_joined' then return new; end if;
 update public.chat_members set hidden_at=null where chat_id=new.chat_id
  and user_id<>new.sender_id and hidden_at is not null and new.created_at>hidden_at;
 return new;
end; $$;

create or replace view public.chat_list with (security_invoker = true) as
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
  members.member_count,
  case when c.chat_kind = 'group' then me.joined_at end as ai_started_at
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
    and m.message_type <> 'group_joined'
    and (c.chat_kind = 'group' or m.created_at >= me.joined_at)
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
    and public.group_ai_eligible(package.message_id,me.user_id)
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
    and m.message_type <> 'group_joined'
    and m.deleted_at is null
    and m.created_at >= me.joined_at
    and not exists (
      select 1 from public.message_reads r
      where r.message_id = m.id and r.user_id = me.user_id
    )
) unread on true
where me.user_id = auth.uid() and me.hidden_at is null;

grant select on table public.chat_list to authenticated;
