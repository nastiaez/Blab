create or replace function public.pair_with_email(
  partner_email text,
  my_learning text,
  partner_learning text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  me uuid := auth.uid();
  partner uuid;
  existing uuid;
  new_chat uuid;
begin
  if me is null then raise exception 'not_signed_in'; end if;

  select id into partner from auth.users
    where lower(email) = lower(trim(partner_email)) limit 1;
  if partner is null then raise exception 'partner_not_found'; end if;
  if partner = me then raise exception 'cannot_pair_with_self'; end if;

  -- Reuse an existing chat that has exactly these two members.
  select c.id into existing
  from public.chats c
  join public.chat_members a on a.chat_id = c.id and a.user_id = me
  join public.chat_members b on b.chat_id = c.id and b.user_id = partner
  limit 1;
  if existing is not null then return existing; end if;

  insert into public.chats default values returning id into new_chat;
  insert into public.chat_members (chat_id, user_id, learning_language)
    values (new_chat, me, my_learning),
           (new_chat, partner, partner_learning);
  return new_chat;
end;
$$;

grant execute on function public.pair_with_email(text, text, text) to authenticated;
