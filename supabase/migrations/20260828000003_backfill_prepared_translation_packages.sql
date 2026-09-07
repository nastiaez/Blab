-- Backfill rows that were already in the provider cache when readiness
-- storage was introduced. The operation is idempotent and viewer-scoped.
insert into public.message_prepared_packages (
  message_id, chat_id, viewer_id, learning_language,
  primary_known_language, language_revision, source_version, status,
  translation_text, interface_text, source_lang, aid_mode, explanation,
  confidence, tokens, form_alternatives, resolved_at
)
select
  mt.message_id,
  m.chat_id,
  cm.user_id,
  cm.learning_language,
  coalesce(p.primary_known_language, p.interface_language, 'en'),
  cm.learning_language_revision,
  mt.source_hash,
  'ready',
  mt.translation_text,
  coalesce(mt.interface_text, mt.translation_text),
  mt.source_lang,
  mt.aid_mode,
  mt.explanation,
  mt.confidence,
  coalesce(mt.tokens, '[]'::jsonb),
  mt.form_alternatives,
  mt.created_at
from public.message_translations mt
join public.messages m on m.id = mt.message_id
join public.chat_members cm on cm.chat_id = m.chat_id
join public.profiles p on p.id = cm.user_id
where cm.learning_language = mt.target_lang
  and coalesce(p.primary_known_language, p.interface_language, 'en') =
    mt.interface_lang
on conflict (message_id, viewer_id, language_revision, source_version)
do nothing;
