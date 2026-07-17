-- L-10: persist reply relationships safely and invalidate translations when
-- their source message is edited.

-- Repair any malformed rows created before reply relationships were enforced.
update public.messages reply
set reply_to = null
where reply.reply_to is not null
  and (
    reply.reply_to = reply.id
    or not exists (
      select 1
      from public.messages target
      where target.id = reply.reply_to
        and target.chat_id = reply.chat_id
    )
  );

alter table public.messages
  drop constraint if exists messages_reply_to_fkey;

alter table public.messages
  add constraint messages_reply_not_self_check
    check (reply_to is null or reply_to <> id),
  add constraint messages_reply_same_chat_fkey
    foreign key (reply_to, chat_id)
    references public.messages (id, chat_id)
    on delete set null (reply_to);

create or replace function public.invalidate_message_translations_on_edit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.body is distinct from old.body then
    delete from public.message_translations
    where message_id = new.id;
  end if;
  return null;
end;
$$;

revoke all on function public.invalidate_message_translations_on_edit()
  from public, anon, authenticated;

drop trigger if exists invalidate_message_translations_on_edit
  on public.messages;
create trigger invalidate_message_translations_on_edit
  after update of body on public.messages
  for each row execute function public.invalidate_message_translations_on_edit();
