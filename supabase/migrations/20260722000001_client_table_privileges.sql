-- Keep client table privileges reproducible in every environment. RLS still
-- decides which rows an authenticated user may access; these grants define the
-- narrower set of operations that can reach those policies at all.

grant usage on schema public to authenticated;

revoke all on table public.profiles from anon, authenticated;
grant select on table public.profiles to authenticated;

revoke all on table public.chats from anon, authenticated;
grant select on table public.chats to authenticated;

revoke all on table public.chat_members from anon, authenticated;
grant select on table public.chat_members to authenticated;
grant update (learning_language) on table public.chat_members to authenticated;

revoke all on table public.messages from anon, authenticated;
grant select, insert on table public.messages to authenticated;
grant update (body, deleted_at) on table public.messages to authenticated;

revoke all on table public.message_reads from anon, authenticated;
grant select on table public.message_reads to authenticated;
grant insert (message_id, user_id, chat_id)
  on table public.message_reads to authenticated;

revoke all on table public.message_translations from anon, authenticated;
grant select on table public.message_translations to authenticated;

revoke all on table public.blocks from anon, authenticated;
grant select, insert, delete on table public.blocks to authenticated;

revoke all on table public.chat_list from anon, authenticated;
grant select on table public.chat_list to authenticated;
