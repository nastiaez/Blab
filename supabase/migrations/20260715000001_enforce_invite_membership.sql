-- Chat membership is consent-based: only the validated claim_invite RPC may
-- create a chat and insert both participants. The old development RPC and
-- direct client insert policies bypassed that boundary.

drop function if exists public.pair_with_email(text, text, text);

drop policy if exists chats_insert_self on public.chats;
drop policy if exists chat_members_insert_self on public.chat_members;

revoke insert on table public.chats from anon, authenticated;
revoke insert on table public.chat_members from anon, authenticated;
