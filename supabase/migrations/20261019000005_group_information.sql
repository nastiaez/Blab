-- BLA-14: roster reads and owner edits are server-authorized at commit time.
create function public.group_members(p_chat_id uuid)
returns table(user_id uuid, display_name text, is_owner boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.is_account_active(auth.uid()) or not exists (
    select 1 from public.chat_members me join public.chats c on c.id=me.chat_id
    where me.chat_id=p_chat_id and me.user_id=auth.uid()
      and c.chat_kind='group' and c.left_at is null
  ) then raise insufficient_privilege using message='group_not_available'; end if;
  return query select p.id, p.display_name, c.owner_id=p.id
    from public.chat_members cm join public.profiles p on p.id=cm.user_id
    join public.chats c on c.id=cm.chat_id where cm.chat_id=p_chat_id
    order by (c.owner_id=p.id) desc, cm.joined_at, p.id;
end; $$;

create function public.rename_group(p_chat_id uuid, group_name text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_account_active(auth.uid()) then
    raise insufficient_privilege using message='group_not_available'; end if;
  if group_name is null or char_length(btrim(group_name)) not between 1 and 60
    or group_name ~ '[[:cntrl:]]' then raise exception 'invalid_group_name'; end if;
  update public.chats c set title=btrim(group_name)
    where c.id=p_chat_id and c.chat_kind='group' and c.owner_id=auth.uid()
      and c.left_at is null and exists(select 1 from public.chat_members cm
        where cm.chat_id=c.id and cm.user_id=auth.uid());
  if not found then raise insufficient_privilege using message='owner_required'; end if;
end; $$;

create function public.transfer_group_owner(p_chat_id uuid, member_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_account_active(auth.uid()) then
    raise insufficient_privilege using message='group_not_available'; end if;
  perform 1 from public.chats c where c.id=p_chat_id and c.chat_kind='group'
    and c.owner_id=auth.uid() and c.left_at is null for update;
  if not found then raise insufficient_privilege using message='owner_required'; end if;
  if not exists(select 1 from public.chat_members cm where cm.chat_id=p_chat_id
    and cm.user_id=member_id) then raise exception 'member_not_found'; end if;
  update public.chats set owner_id=member_id where id=p_chat_id;
end; $$;

revoke all on function public.group_members(uuid), public.rename_group(uuid,text),
  public.transfer_group_owner(uuid,uuid) from public, anon;
grant execute on function public.group_members(uuid), public.rename_group(uuid,text),
  public.transfer_group_owner(uuid,uuid) to authenticated;
