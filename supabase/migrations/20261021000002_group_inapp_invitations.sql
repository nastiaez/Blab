-- Individual invitations are private inbox entries, never chat messages or membership.
alter table public.pending_group_invitations add column invited_by uuid references public.profiles(id) on delete set null;

create function public.group_invite_friends(p_chat_id uuid)
returns table(user_id uuid,display_name text,invited boolean)
language plpgsql stable security definer set search_path=public as $$
begin
 if not public.is_account_active(auth.uid()) or not exists(
  select 1 from public.chats g join public.chat_members me on me.chat_id=g.id
  where g.id=p_chat_id and g.chat_kind='group' and g.left_at is null
   and me.user_id=auth.uid() and me.hidden_at is null
 ) then raise insufficient_privilege using message='group_not_available'; end if;
 return query
 select distinct p.id,p.display_name,exists(select 1 from public.pending_group_invitations i
  join public.group_invites gi on gi.token=i.token and gi.revoked_at is null
  where i.user_id=p.id and i.chat_id=p_chat_id)
 from public.chats c join public.chat_members me on me.chat_id=c.id and me.user_id=auth.uid()
 join public.chat_members friend on friend.chat_id=c.id and friend.user_id<>auth.uid()
 join public.profiles p on p.id=friend.user_id
 where c.chat_kind='direct' and c.left_at is null and me.hidden_at is null
 and public.is_account_active(p.id)
 and not exists(select 1 from public.blocks b where
  (b.blocker_id=auth.uid() and b.blocked_id=p.id) or (b.blocker_id=p.id and b.blocked_id=auth.uid()))
 and not exists(select 1 from public.member_contact_requests r where r.chat_id=c.id and r.accepted_at is null)
 and not exists(select 1 from public.chat_members member where member.chat_id=p_chat_id and member.user_id=p.id)
 order by p.display_name,p.id;
end; $$;

create function public.send_group_invitations(p_chat_id uuid,p_recipient_ids uuid[])
returns integer language plpgsql security definer set search_path=public as $$
declare t text; n integer; eligible integer;
begin
 if p_recipient_ids is null or cardinality(p_recipient_ids) not between 1 and 100
  or array_position(p_recipient_ids,null) is not null then raise exception 'invalid_recipients'; end if;
 perform 1 from public.chats where id=p_chat_id for update;
 -- Same serialized capability as ordinary link sharing; no automatic membership.
 select token into t from public.create_group_invite(p_chat_id);
 select count(distinct x) into n from unnest(p_recipient_ids) x;
 select count(*) into eligible from public.group_invite_friends(p_chat_id) f where f.user_id=any(p_recipient_ids);
 if eligible<>n then raise insufficient_privilege using message='recipient_not_available'; end if;
 if (select count(*) from public.chat_members where chat_id=p_chat_id)>=100 then raise exception 'group_full'; end if;
 insert into public.pending_group_invitations(user_id,chat_id,token,invited_by,created_at)
 select x,p_chat_id,t,auth.uid(),clock_timestamp() from (select distinct unnest(p_recipient_ids) x) recipients
 on conflict(user_id,chat_id) do update set token=excluded.token,
  invited_by=coalesce(pending_group_invitations.invited_by,excluded.invited_by),
  created_at=case when pending_group_invitations.invited_by is null then excluded.created_at else pending_group_invitations.created_at end,
  viewed_at=case when pending_group_invitations.token=excluded.token then pending_group_invitations.viewed_at else null end;
 return n;
end; $$;

-- Regenerating a public link must not silently cancel individual invitations.
alter function public.replace_group_invite(uuid) rename to replace_group_invite_link;
revoke all on function public.replace_group_invite_link(uuid) from public,anon,authenticated;
create function public.replace_group_invite(p_chat_id uuid)
returns table(token text) language plpgsql security definer set search_path=public as $$
declare t text;
begin
 select gi.token into t from public.replace_group_invite_link(p_chat_id) gi;
 update public.pending_group_invitations i set token=t where i.chat_id=p_chat_id and i.invited_by is not null;
 return query select t;
end; $$;
revoke all on function public.group_invite_friends(uuid),public.send_group_invitations(uuid,uuid[]),public.replace_group_invite(uuid) from public,anon;
grant execute on function public.group_invite_friends(uuid),public.send_group_invitations(uuid,uuid[]),public.replace_group_invite(uuid) to authenticated;
-- Publish only a recipient-private revision, never invitation ids on DELETE.
create table public.group_invitation_inboxes (
 user_id uuid primary key references public.profiles(id) on delete cascade,
 revision bigint not null default 0
);
alter table public.group_invitation_inboxes enable row level security;
revoke all on public.group_invitation_inboxes from public,anon,authenticated;
grant select on public.group_invitation_inboxes to authenticated;
create policy group_invitation_inbox_own on public.group_invitation_inboxes for select to authenticated
 using(user_id=auth.uid() and public.is_account_active(auth.uid()));
create function public.notify_group_invitation_inbox() returns trigger
language plpgsql security definer set search_path=public as $$
declare u uuid:=case when TG_OP='DELETE' then old.user_id else new.user_id end;
begin
 if exists(select 1 from public.profiles where id=u) then
  insert into public.group_invitation_inboxes(user_id,revision) values(u,1)
  on conflict(user_id) do update set revision=group_invitation_inboxes.revision+1;
 end if;
 return null;
end; $$;
revoke all on function public.notify_group_invitation_inbox() from public,anon,authenticated;
create trigger group_invitation_inbox_changed after insert or update or delete on public.pending_group_invitations
 for each row execute function public.notify_group_invitation_inbox();
alter publication supabase_realtime add table public.group_invitation_inboxes;
-- Deleting an inviter's account must not be blocked by a pending link FK.
alter table public.pending_group_invitations drop constraint pending_group_invitations_token_fkey;
alter table public.pending_group_invitations add constraint pending_group_invitations_token_fkey
 foreign key(token) references public.group_invites(token) on delete cascade;

-- A private new invitation can re-invite its named removed recipient without
-- reviving the old shared link for any other removed user.
create or replace function public.join_group(invite_token text)
returns table(chat_id uuid,already_member boolean)
language plpgsql security definer set search_path=public as $$
declare joined record; invitation public.group_invites%rowtype;
begin
 select * into invitation from public.group_invites where token=invite_token;
 if found then
  perform 1 from public.chats where id=invitation.chat_id for update;
  if exists(select 1 from public.group_departures d where d.chat_id=invitation.chat_id
   and d.user_id=auth.uid() and d.removed and invitation.created_at<=d.departed_at
   and not exists(select 1 from public.pending_group_invitations i
    where i.chat_id=d.chat_id and i.user_id=d.user_id and i.token=invite_token
     and i.invited_by is not null and i.created_at>d.departed_at)) then
   raise exception 'fresh_group_invitation_required';
  end if;
 end if;
 select * into joined from public.join_group_membership(invite_token);
 delete from public.pending_group_invitations p where p.user_id=auth.uid() and p.chat_id=joined.chat_id;
 return query select joined.chat_id::uuid,joined.already_member::boolean;
end; $$;
