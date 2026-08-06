-- Minimal private photo attachments for chat messages.

alter table public.messages
  add column if not exists message_type text not null default 'text'
    check (message_type in ('text', 'image'));

create table if not exists public.message_attachments (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null,
  chat_id uuid not null,
  storage_bucket text not null default 'message-media',
  storage_path text not null,
  mime_type text not null,
  byte_size integer not null check (byte_size > 0),
  created_at timestamptz not null default now(),
  unique (message_id),
  unique (storage_bucket, storage_path),
  foreign key (message_id, chat_id)
    references public.messages (id, chat_id)
    on delete cascade
);

create index if not exists message_attachments_chat_idx
  on public.message_attachments (chat_id, message_id);

alter table public.message_attachments enable row level security;
alter table public.message_attachments replica identity full;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'message-media',
  'message-media',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update
set
  public = false,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy message_attachments_select_member
  on public.message_attachments
  for select
  using (
    exists (
      select 1
      from public.chat_members cm
      where cm.chat_id = message_attachments.chat_id
        and cm.user_id = auth.uid()
    )
  );

create policy message_attachments_insert_sender
  on public.message_attachments
  for insert
  with check (
    storage_bucket = 'message-media'
    and exists (
      select 1
      from public.messages m
      where m.id = message_attachments.message_id
        and m.chat_id = message_attachments.chat_id
        and m.sender_id = auth.uid()
        and m.message_type = 'image'
    )
  );

create policy message_attachments_delete_sender
  on public.message_attachments
  for delete
  using (
    exists (
      select 1
      from public.messages m
      where m.id = message_attachments.message_id
        and m.chat_id = message_attachments.chat_id
        and m.sender_id = auth.uid()
    )
  );

drop policy if exists message_media_select_member on storage.objects;
create policy message_media_select_member
  on storage.objects
  for select
  using (
    bucket_id = 'message-media'
    and split_part(storage.objects.name, '/', 1) ~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and exists (
      select 1
      from public.chat_members cm
      where cm.chat_id = split_part(storage.objects.name, '/', 1)::uuid
        and cm.user_id = auth.uid()
    )
  );

drop policy if exists message_media_insert_member on storage.objects;
create policy message_media_insert_member
  on storage.objects
  for insert
  with check (
    bucket_id = 'message-media'
    and split_part(storage.objects.name, '/', 1) ~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and split_part(storage.objects.name, '/', 2) ~*
      '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and split_part(storage.objects.name, '/', 2)::uuid = auth.uid()
    and exists (
      select 1
      from public.chat_members cm
      where cm.chat_id = split_part(storage.objects.name, '/', 1)::uuid
        and cm.user_id = auth.uid()
    )
  );

drop policy if exists message_media_update_owner on storage.objects;
create policy message_media_update_owner
  on storage.objects
  for update
  using (
    bucket_id = 'message-media'
    and owner = auth.uid()
  )
  with check (
    bucket_id = 'message-media'
    and owner = auth.uid()
  );

drop policy if exists message_media_delete_owner on storage.objects;
create policy message_media_delete_owner
  on storage.objects
  for delete
  using (
    bucket_id = 'message-media'
    and owner = auth.uid()
  );

revoke all on table public.message_attachments from anon, authenticated;
grant select, insert, delete on table public.message_attachments to authenticated;

alter publication supabase_realtime add table public.message_attachments;
