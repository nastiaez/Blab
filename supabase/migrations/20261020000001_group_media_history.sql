-- BLA-14: history isolation applies to metadata and storage, not only bubbles.
create function public.group_message_history_visible(p_message_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select coalesce((select public.group_history_visible(m.chat_id,m.created_at)
    from public.messages m where m.id=p_message_id),false);
$$;
revoke all on function public.group_message_history_visible(uuid) from public,anon;
grant execute on function public.group_message_history_visible(uuid) to authenticated;

create policy group_attachment_history on public.message_attachments
  as restrictive for select to authenticated
  using (public.group_message_history_visible(message_id));
create policy group_package_history on public.message_prepared_packages
  as restrictive for select to authenticated
  using (public.group_message_history_visible(message_id));
create policy group_read_history on public.message_reads
  as restrictive for select to authenticated
  using (public.group_message_history_visible(message_id));
create policy group_reaction_history on public.message_reactions
  as restrictive for select to authenticated
  using (public.group_message_history_visible(message_id));

create function public.group_storage_history_visible(p_bucket text,p_name text)
returns boolean language plpgsql stable security definer set search_path=public as $$
declare cid uuid;
begin
  if p_bucket<>'message-media' then return true; end if;
  begin cid:=split_part(p_name,'/',1)::uuid;
  exception when invalid_text_representation then return false; end;
  if not exists(select 1 from public.chats c where c.id=cid and c.chat_kind='group')
    then return true; end if;
  return exists(select 1 from public.message_attachments a
    join public.messages m on m.id=a.message_id
    where a.chat_id=cid and a.storage_bucket=p_bucket
      and (a.storage_path=p_name or a.preview_storage_path=p_name)
      and m.deleted_at is null
      and public.group_history_visible(cid,m.created_at));
end; $$;
revoke all on function public.group_storage_history_visible(text,text) from public,anon;
grant execute on function public.group_storage_history_visible(text,text) to authenticated;
create policy group_storage_history on storage.objects
  as restrictive for select to authenticated
  using(public.group_storage_history_visible(bucket_id,name));
