-- Report + Block — required by Google Play's UGC / child-safety policy for
-- social apps (Step 3.6a). Two tables: `blocks` (who has blocked whom) and
-- `reports` (abuse reports for review).

-- blocks: blocker_id has blocked blocked_id. Symmetric effect is enforced in
-- the messages RLS below (a blocked user can't post into a shared chat).
create table public.blocks (
  blocker_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id)
);
create index blocks_blocker_idx on public.blocks (blocker_id);
create index blocks_blocked_idx on public.blocks (blocked_id);

alter table public.blocks enable row level security;

-- You manage only your own block list.
create policy blocks_select_own on public.blocks
  for select to authenticated using (blocker_id = auth.uid());
create policy blocks_insert_own on public.blocks
  for insert to authenticated with check (blocker_id = auth.uid());
create policy blocks_delete_own on public.blocks
  for delete to authenticated using (blocker_id = auth.uid());

-- reports: an abuse report. reported_user / chat / message are all optional
-- so a report can target a person, a chat, or a single message.
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles (id) on delete cascade,
  reported_user_id uuid references public.profiles (id) on delete set null,
  chat_id uuid references public.chats (id) on delete set null,
  message_id uuid references public.messages (id) on delete set null,
  reason text not null,
  details text,
  created_at timestamptz not null default now()
);
create index reports_created_idx on public.reports (created_at desc);

alter table public.reports enable row level security;

-- You can file a report as yourself, and read back your own reports. No one
-- reads others' reports from the client (review happens server-side / admin).
create policy reports_insert_own on public.reports
  for insert to authenticated with check (reporter_id = auth.uid());
create policy reports_select_own on public.reports
  for select to authenticated using (reporter_id = auth.uid());

-- Block enforcement: a user cannot insert a message into a chat that has a
-- member who has blocked them. This makes "block stops their messages
-- reaching you" true server-side, not just hidden client-side.
--
-- Uses a SECURITY DEFINER helper (mirrors public.is_chat_member) so the
-- subquery on chat_members + blocks bypasses RLS and can't recurse.
create or replace function public.is_blocked_in_chat(p_chat_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_members other
    join public.blocks b
      on b.blocker_id = other.user_id
     and b.blocked_id = auth.uid()
    where other.chat_id = p_chat_id
      and other.user_id <> auth.uid()
  );
$$;

drop policy if exists messages_insert_sender on public.messages;
create policy messages_insert_sender on public.messages
  for insert to authenticated with check (
    auth.uid() = sender_id
    and public.is_chat_member(chat_id)
    and not public.is_blocked_in_chat(chat_id)
  );

-- Surface a blocker's own block changes in realtime so their chat list
-- updates the moment they block/unblock.
alter publication supabase_realtime add table public.blocks;
