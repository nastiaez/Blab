-- Read-only, one-statement consistent source for an operator-held migration.
-- Never export private translations, learning settings, auth or device tokens.
with source as (
  select jsonb_build_object(
    'profiles', coalesce((select jsonb_agg(to_jsonb(p) order by p.id) from (
      select id, display_name, created_at, avatar_path from public.profiles
      where id in (select user_id from public.chat_members)
    ) p), '[]'::jsonb),
    'chats', coalesce((select jsonb_agg(to_jsonb(c) order by c.id) from (
      select id, created_at from public.chats
    ) c), '[]'::jsonb),
    'members', coalesce((select jsonb_agg(to_jsonb(m) order by m.chat_id, m.user_id) from (
      select chat_id, user_id, joined_at from public.chat_members
    ) m), '[]'::jsonb),
    'messages', coalesce((select jsonb_agg(to_jsonb(m) order by m.created_at, m.id) from (
      select id, chat_id, sender_id, body, created_at, edited_at, deleted_at,
        reply_to, message_type, languages_matched_at_send from public.messages
    ) m), '[]'::jsonb),
    'reads', coalesce((select jsonb_agg(to_jsonb(r) order by r.message_id, r.user_id) from (
      select message_id, user_id, read_at, receipt_visible from public.message_reads
    ) r), '[]'::jsonb),
    'reactions', coalesce((select jsonb_agg(to_jsonb(r) order by r.message_id, r.user_id) from (
      select message_id, chat_id, user_id, emoji, created_at from public.message_reactions
    ) r), '[]'::jsonb),
    'attachments', coalesce((select jsonb_agg(to_jsonb(a) order by a.message_id) from (
      select id, message_id, chat_id, storage_bucket, storage_path, mime_type,
        byte_size, preview_storage_path, preview_mime_type, preview_byte_size
      from public.message_attachments
    ) a), '[]'::jsonb)
  ) as snapshot
)
select snapshot, encode(extensions.digest(snapshot::text, 'sha256'), 'hex') as fingerprint
from source;
