-- Opening a group link records a private invitation, not membership.
create table public.pending_group_invitations (
  user_id uuid not null references public.profiles(id) on delete cascade,
  chat_id uuid not null references public.chats(id) on delete cascade,
  token text not null references public.group_invites(token),
  created_at timestamptz not null default now(),
  viewed_at timestamptz,
  primary key (user_id, chat_id)
);
alter table public.pending_group_invitations enable row level security;
revoke all on public.pending_group_invitations from public, anon, authenticated;
grant select on public.pending_group_invitations to authenticated;
create policy pending_group_invites_own on public.pending_group_invitations
for select to authenticated using (user_id=auth.uid());

create function public.register_group_invitation(invite_token text)
returns void language plpgsql security definer set search_path=public as $$
declare u uuid:=auth.uid(); g public.group_invites%rowtype;
begin
 if u is null or not public.is_account_active(u) then raise insufficient_privilege; end if;
 select * into g from public.group_invites where token=invite_token and revoked_at is null;
 if not found or exists(select 1 from public.chats where id=g.chat_id and left_at is not null) then raise exception 'group_invite_unavailable'; end if;
 if exists(select 1 from public.chat_members where chat_id=g.chat_id and user_id=u) then return; end if;
 insert into public.pending_group_invitations(user_id,chat_id,token)
 values(u,g.chat_id,g.token)
 on conflict(user_id,chat_id) do update set
   viewed_at=case when pending_group_invitations.token=excluded.token then pending_group_invitations.viewed_at else null end,
   token=excluded.token;
end; $$;

create function public.list_pending_group_invitations()
returns table(token text,chat_id uuid,group_name text,member_count integer,created_at timestamptz,viewed_at timestamptz)
language sql stable security definer set search_path=public as $$
 select p.token,p.chat_id,c.title,
 (select count(*)::int from public.chat_members cm where cm.chat_id=p.chat_id),
 p.created_at,p.viewed_at
 from public.pending_group_invitations p join public.chats c on c.id=p.chat_id
 where p.user_id=auth.uid() and public.is_account_active(auth.uid())
 and not exists(select 1 from public.chat_members cm where cm.chat_id=p.chat_id and cm.user_id=auth.uid())
 order by p.created_at desc;
$$;

create function public.view_group_invitation(invite_token text)
returns void language sql security definer set search_path=public as $$
 update public.pending_group_invitations set viewed_at=coalesce(viewed_at,now())
 where token=invite_token and user_id=auth.uid();
$$;
create function public.reject_group_invitation(invite_token text)
returns void language sql security definer set search_path=public as $$
 delete from public.pending_group_invitations where token=invite_token and user_id=auth.uid();
$$;

alter function public.join_group(text) rename to join_group_membership;
revoke all on function public.join_group_membership(text) from public,anon,authenticated;
create function public.join_group(invite_token text)
returns table(chat_id uuid,already_member boolean)
language plpgsql security definer set search_path=public as $$
declare joined record;
begin
 select * into joined from public.join_group_membership(invite_token);
 delete from public.pending_group_invitations p where p.user_id=auth.uid() and p.chat_id=joined.chat_id;
 return query select joined.chat_id::uuid,joined.already_member::boolean;
end; $$;

revoke all on function public.register_group_invitation(text),public.list_pending_group_invitations(),public.view_group_invitation(text),public.reject_group_invitation(text),public.join_group(text) from public,anon;
grant execute on function public.register_group_invitation(text),public.list_pending_group_invitations(),public.view_group_invitation(text),public.reject_group_invitation(text),public.join_group(text) to authenticated;
