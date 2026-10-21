-- Preserve shared groups when an account is permanently deleted. Ordinary
-- Leave continues to require explicit owner transfer; erasure cannot strand
-- the remaining members or fail the owner's account deletion FK checks.
create function public.handover_groups_before_account_erasure() returns trigger
language plpgsql security definer set search_path=public as $$
declare c record; next_owner uuid;
begin
 for c in select id from public.chats where chat_kind='group' and owner_id=old.id order by id for update loop
  select cm.user_id into next_owner from public.chat_members cm
   where cm.chat_id=c.id and cm.user_id<>old.id and cm.chat_left_at is null
   order by public.is_account_active(cm.user_id) desc,cm.joined_at,cm.user_id limit 1;
  if next_owner is null then delete from public.chats where id=c.id;
  else update public.chats set owner_id=next_owner where id=c.id; end if;
 end loop;
 return old;
end; $$;
create trigger handover_groups_before_account_erasure before delete on public.profiles
 for each row execute function public.handover_groups_before_account_erasure();
revoke all on function public.handover_groups_before_account_erasure() from public,anon,authenticated;
