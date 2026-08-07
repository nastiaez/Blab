-- The insert/update policies on message_reactions correlated the EXISTS
-- subquery's messages.chat_id back to itself (`m.chat_id = m.chat_id`,
-- always true) instead of to the outer message_reactions row's chat_id, so
-- the "message actually belongs to this chat" check was a no-op. The
-- (message_id, chat_id) foreign key already prevents mismatched pairs at
-- the data level, so this was never exploitable, but the check should
-- actually check what it claims to.

drop policy message_reactions_insert_self on public.message_reactions;
drop policy message_reactions_update_self on public.message_reactions;

create policy message_reactions_insert_self
  on public.message_reactions
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and public.is_account_active(auth.uid())
    and public.is_chat_member(chat_id)
    and exists (
      select 1
      from public.messages m
      where m.id = message_reactions.message_id
        and m.chat_id = message_reactions.chat_id
        and m.deleted_at is null
    )
  );

create policy message_reactions_update_self
  on public.message_reactions
  for update to authenticated
  using (
    user_id = auth.uid()
    and public.is_account_active(auth.uid())
    and public.is_chat_member(chat_id)
  )
  with check (
    user_id = auth.uid()
    and public.is_account_active(auth.uid())
    and public.is_chat_member(chat_id)
    and exists (
      select 1
      from public.messages m
      where m.id = message_reactions.message_id
        and m.chat_id = message_reactions.chat_id
        and m.deleted_at is null
    )
  );
