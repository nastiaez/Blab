-- profiles: 1:1 with auth.users
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  avatar_path text,
  interface_language text not null default 'en',
  created_at timestamptz not null default now()
);

-- Auto-create a profile row when a user signs up
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', ''));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- chats: one row per conversation, symmetric (no owner)
create table public.chats (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);

-- chat_members: who is in which chat, what they learn from the other
create table public.chat_members (
  chat_id uuid not null references public.chats (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  learning_language text not null,
  joined_at timestamptz not null default now(),
  primary key (chat_id, user_id)
);
create index chat_members_user_id_idx on public.chat_members (user_id);

-- messages: plaintext body for now (Step 2.6 swaps in ciphertext columns)
create table public.messages (
  id uuid primary key default gen_random_uuid(),
  chat_id uuid not null references public.chats (id) on delete cascade,
  sender_id uuid not null references public.profiles (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  reply_to uuid references public.messages (id) on delete set null,
  deleted_at timestamptz
);
create index messages_chat_created_idx
  on public.messages (chat_id, created_at desc);

-- message_reads: per-message, per-reader. Idempotent via composite PK.
create table public.message_reads (
  message_id uuid not null references public.messages (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  read_at timestamptz not null default now(),
  chat_id uuid not null,
  primary key (message_id, user_id)
);
create index message_reads_chat_user_idx
  on public.message_reads (chat_id, user_id);

-- Realtime publication: include chats, chat_members, messages, message_reads
alter publication supabase_realtime add table public.chats;
alter publication supabase_realtime add table public.chat_members;
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.message_reads;
