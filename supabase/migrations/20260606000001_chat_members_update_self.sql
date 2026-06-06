-- Allow a user to update their own chat_members row. Used by the
-- "Learning language" sheet so picking a new language persists. The
-- RLS check restricts edits to the caller's own row in the targeted chat.
create policy chat_members_update_self on public.chat_members
  for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
