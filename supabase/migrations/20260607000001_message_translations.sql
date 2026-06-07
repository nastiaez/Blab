-- Per-message, per-target-language translation cache so reopening a
-- chat doesn't re-fire the LLM for every old message. Each (message,
-- target) pair is stored once; first viewer to translate populates it,
-- subsequent viewers + repeat sessions read the cached row.
create table public.message_translations (
  message_id uuid not null references public.messages (id) on delete cascade,
  target_lang text not null,
  translation_text text not null,
  tokens jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  primary key (message_id, target_lang)
);

create index message_translations_lookup
  on public.message_translations (message_id, target_lang);

alter table public.message_translations enable row level security;

-- Members of the chat that owns this message can read translations
-- of any of its messages, in any target language.
create policy message_translations_select on public.message_translations
  for select to authenticated using (
    exists (
      select 1
      from public.messages m
      join public.chat_members cm on cm.chat_id = m.chat_id
      where m.id = message_translations.message_id
        and cm.user_id = auth.uid()
    )
  );

-- And can insert cache entries for messages in chats they belong to.
create policy message_translations_insert on public.message_translations
  for insert to authenticated with check (
    exists (
      select 1
      from public.messages m
      join public.chat_members cm on cm.chat_id = m.chat_id
      where m.id = message_translations.message_id
        and cm.user_id = auth.uid()
    )
  );
