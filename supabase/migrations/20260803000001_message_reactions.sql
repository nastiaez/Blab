-- Free emoji reactions: one reaction per user per message, visible only to
-- members of the message's chat.

create table public.message_reactions (
  message_id uuid not null,
  chat_id uuid not null,
  user_id uuid not null references auth.users (id) on delete cascade,
  emoji text not null check (
    char_length(btrim(emoji)) between 1 and 32
    and emoji = btrim(emoji)
  ),
  created_at timestamptz not null default now(),
  primary key (message_id, user_id),
  foreign key (message_id, chat_id)
    references public.messages (id, chat_id)
    on delete cascade
);

create index message_reactions_chat_idx
  on public.message_reactions (chat_id, message_id);

alter table public.message_reactions enable row level security;
alter table public.message_reactions replica identity full;

create policy message_reactions_select_member
  on public.message_reactions
  for select to authenticated
  using (
    public.is_account_active(auth.uid())
    and public.is_chat_member(chat_id)
  );

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
      where m.id = message_id
        and m.chat_id = chat_id
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
      where m.id = message_id
        and m.chat_id = chat_id
        and m.deleted_at is null
    )
  );

create policy message_reactions_delete_self
  on public.message_reactions
  for delete to authenticated
  using (
    user_id = auth.uid()
    and public.is_account_active(auth.uid())
    and public.is_chat_member(chat_id)
  );

revoke all on table public.message_reactions from anon, authenticated;
grant select on table public.message_reactions to authenticated;
grant insert (message_id, chat_id, user_id, emoji)
  on table public.message_reactions to authenticated;
grant update (emoji)
  on table public.message_reactions to authenticated;
grant delete on table public.message_reactions to authenticated;

alter publication supabase_realtime add table public.message_reactions;
