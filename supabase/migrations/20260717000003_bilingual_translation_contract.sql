-- L-12: cache both normalized display forms and the detected source language.

alter table public.message_translations
  add column english_text text,
  add column source_lang text;

-- Every pre-L-12 cache row was produced by the English-pivot contract.
update public.message_translations mt
set english_text = m.body,
    source_lang = 'en'
from public.messages m
where m.id = mt.message_id;

alter table public.message_translations
  alter column english_text set not null,
  alter column source_lang set not null,
  add constraint message_translations_source_lang_check
    check (source_lang in ('nl', 'en', 'fr', 'de', 'hi', 'it', 'pt', 'es', 'ta', 'tr', 'uk'));
