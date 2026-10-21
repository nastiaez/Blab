-- Storage upserts require SELECT before attachment metadata has been committed.
create or replace function public.group_storage_history_visible(p_bucket text,p_name text)
returns boolean language plpgsql stable security definer set search_path=public as $$
declare cid uuid;
begin
  if p_bucket<>'message-media' then return true; end if;
  begin cid:=split_part(p_name,'/',1)::uuid;
  exception when invalid_text_representation then return false; end;
  if not exists(select 1 from public.chats c where c.id=cid and c.chat_kind='group')
    then return true; end if;
  if split_part(p_name,'/',2)=auth.uid()::text and exists(
    select 1 from public.chat_members cm join public.chats c on c.id=cm.chat_id
    where cm.chat_id=cid and cm.user_id=auth.uid() and cm.chat_left_at is null
      and c.left_at is null
  ) then return true; end if;
  return exists(select 1 from public.message_attachments a
    join public.messages m on m.id=a.message_id
    where a.chat_id=cid and a.storage_bucket=p_bucket
      and (a.storage_path=p_name or a.preview_storage_path=p_name)
      and m.deleted_at is null
      and public.group_history_visible(cid,m.created_at));
end; $$;
