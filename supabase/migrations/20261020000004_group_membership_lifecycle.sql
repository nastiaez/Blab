-- Topic7420 /14560,14566,14578. Originals and AI eligibility are independent.
alter table public.group_invites alter column created_at set default clock_timestamp();
create table public.group_departures (
 chat_id uuid not null references public.chats(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 departed_at timestamptz not null,
 removed boolean not null,
 primary key(chat_id,user_id)
);
alter table public.group_departures enable row level security;
revoke all on public.group_departures from public,anon,authenticated;

create or replace function public.group_history_visible(p_chat_id uuid,p_created_at timestamptz)
returns boolean language sql stable security definer set search_path=public as $$
 select case when c.chat_kind='direct' then true else exists(
  select 1 from public.chat_members cm where cm.chat_id=c.id
   and cm.user_id=auth.uid() and cm.chat_left_at is null
 ) and c.left_at is null end from public.chats c where c.id=p_chat_id;
$$;

create function public.group_ai_eligible(p_message_id uuid,p_viewer_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select coalesce((select c.chat_kind='direct' or (c.left_at is null and exists(
  select 1 from public.chat_members cm where cm.chat_id=m.chat_id
   and cm.user_id=p_viewer_id and cm.chat_left_at is null
   and m.created_at>=cm.joined_at
 )) from public.messages m join public.chats c on c.id=m.chat_id
 where m.id=p_message_id),false);
$$;
revoke all on function public.group_ai_eligible(uuid,uuid) from public,anon;
grant execute on function public.group_ai_eligible(uuid,uuid) to authenticated,service_role;

-- Epochs are server owned. Rejoin inserts a new membership, not a preference reset.
create function public.guard_group_join_boundary() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if TG_OP='INSERT' then
  if exists(select 1 from public.chats where id=new.chat_id and chat_kind='group') then
   new.joined_at:=clock_timestamp();
  end if;
 elsif new.joined_at is distinct from old.joined_at then
  raise insufficient_privilege using message='membership_boundary_immutable';
 end if;
 return new;
end; $$;
create trigger guard_group_join_boundary before insert or update on public.chat_members
 for each row execute function public.guard_group_join_boundary();

-- Initial language setup can scan originals but cannot enqueue historical work.
create function public.guard_group_ai_job() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if not public.group_ai_eligible(new.message_id,new.viewer_id) then return null; end if;
 return new;
end; $$;
create trigger a_guard_group_ai_job before insert on public.message_preparation_jobs
 for each row execute function public.guard_group_ai_job();
create policy group_package_ai_epoch on public.message_prepared_packages as restrictive
 for select to authenticated using(public.group_ai_eligible(message_id,auth.uid()));
create policy group_readable_ai_epoch on public.message_readable_variants as restrictive
 for select to authenticated using(public.group_ai_eligible(message_id,auth.uid()));
create policy group_legacy_ai_epoch on public.message_translations as restrictive
 for select to authenticated using(public.group_ai_eligible(message_id,auth.uid()));

alter function public.resolve_message_learning_era(uuid,uuid) rename to resolve_message_learning_era_before_group_epoch;
revoke all on function public.resolve_message_learning_era_before_group_epoch(uuid,uuid) from public,anon,authenticated,service_role;
create function public.resolve_message_learning_era(p_message_id uuid,p_viewer_id uuid)
returns table(learning_language text,language_revision bigint,started_at timestamptz)
language sql stable security definer set search_path=public as $$
 select era.* from public.resolve_message_learning_era_before_group_epoch(p_message_id,p_viewer_id) era
 where public.group_ai_eligible(p_message_id,p_viewer_id);
$$;
revoke all on function public.resolve_message_learning_era(uuid,uuid) from public,anon;
grant execute on function public.resolve_message_learning_era(uuid,uuid) to authenticated,service_role;

create function public.end_group_membership(p_chat_id uuid,p_member_id uuid,p_removed boolean)
returns void language plpgsql security definer set search_path=public as $$
declare u uuid:=auth.uid(); c public.chats%rowtype; n integer;
begin
 if u is null or not public.is_account_active(u) then raise insufficient_privilege; end if;
 select * into c from public.chats where id=p_chat_id and chat_kind='group' for update;
 if not found then raise insufficient_privilege using message='group_not_available'; end if;
 if p_removed then
  if c.owner_id<>u or p_member_id=u then raise insufficient_privilege using message='owner_required'; end if;
 elsif p_member_id<>u then raise insufficient_privilege; end if;
 -- Authorized repetitions are harmless, including a last-member close retry.
 if not exists(select 1 from public.chat_members where chat_id=p_chat_id and user_id=p_member_id) then return; end if;
 if c.left_at is not null then raise insufficient_privilege; end if;
 select count(*) into n from public.chat_members where chat_id=p_chat_id;
 if c.owner_id=p_member_id and n>1 then raise exception 'owner_transfer_required'; end if;
 insert into public.group_departures(chat_id,user_id,departed_at,removed)
 values(p_chat_id,p_member_id,clock_timestamp(),p_removed)
 on conflict(chat_id,user_id) do update set departed_at=excluded.departed_at,removed=excluded.removed;
 delete from public.message_preparation_jobs where chat_id=p_chat_id and viewer_id=p_member_id;
 delete from public.message_prepared_packages where chat_id=p_chat_id and viewer_id=p_member_id;
 delete from public.message_readable_variants where chat_id=p_chat_id and viewer_id=p_member_id;
 delete from public.message_translation_attempts where viewer_id=p_member_id and message_id in(select id from public.messages where chat_id=p_chat_id);
 delete from public.pending_group_invitations where chat_id=p_chat_id and user_id=p_member_id;
 delete from public.chat_members where chat_id=p_chat_id and user_id=p_member_id;
 if n=1 then
  update public.chats set left_at=clock_timestamp(),left_by=u where id=p_chat_id;
  update public.group_invites set revoked_at=clock_timestamp() where chat_id=p_chat_id and revoked_at is null;
 end if;
end; $$;
revoke all on function public.end_group_membership(uuid,uuid,boolean) from public,anon,authenticated;
create function public.leave_group(p_chat_id uuid) returns void
language sql security definer set search_path=public as $$
 select public.end_group_membership(p_chat_id,auth.uid(),false);
$$;
create function public.remove_group_member(p_chat_id uuid,p_member_id uuid) returns void
language sql security definer set search_path=public as $$
 select public.end_group_membership(p_chat_id,p_member_id,true);
$$;
revoke all on function public.leave_group(uuid),public.remove_group_member(uuid,uuid) from public,anon;
grant execute on function public.leave_group(uuid),public.remove_group_member(uuid,uuid) to authenticated;

-- Existing join implementation owns token validity and the locked 100-person cap.
create or replace function public.join_group(invite_token text)
returns table(chat_id uuid,already_member boolean)
language plpgsql security definer set search_path=public as $$
declare joined record; invitation public.group_invites%rowtype;
begin
 select * into invitation from public.group_invites where token=invite_token;
 if found then
  perform 1 from public.chats where id=invitation.chat_id for update;
  if exists(select 1 from public.group_departures d where d.chat_id=invitation.chat_id
   and d.user_id=auth.uid() and d.removed and invitation.created_at<=d.departed_at) then
   raise exception 'fresh_group_invitation_required';
  end if;
 end if;
 select * into joined from public.join_group_membership(invite_token);
 delete from public.pending_group_invitations p where p.user_id=auth.uid() and p.chat_id=joined.chat_id;
 return query select joined.chat_id::uuid,joined.already_member::boolean;
end; $$;

-- Prevent stale send-time work from recreating translated history after rejoin.
create function public.guard_group_ai_write() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if not public.group_ai_eligible(new.message_id,new.viewer_id) then
  raise insufficient_privilege using message='translation_epoch_expired';
 end if;
 return new;
end; $$;
create trigger a_guard_group_ai_write before insert or update on public.message_prepared_packages
 for each row execute function public.guard_group_ai_write();
create trigger a_guard_group_ai_write before insert or update on public.message_readable_variants
 for each row execute function public.guard_group_ai_write();

revoke all on function public.guard_group_join_boundary(),public.guard_group_ai_job(),public.guard_group_ai_write() from public,anon,authenticated;

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
    and m.deleted_at is null
    and m.created_at >= me.joined_at
    and not exists (
      select 1 from public.message_reads r
      where r.message_id = m.id and r.user_id = me.user_id
    )
) unread on true
where me.user_id = auth.uid() and me.hidden_at is null;

grant select on table public.chat_list to authenticated;
