begin;

select plan(5);

select has_column(
  'public',
  'message_translations',
  'english_text',
  'translation cache stores the normalized English text'
);

select col_not_null(
  'public',
  'message_translations',
  'english_text',
  'cached English text is required'
);

select has_column(
  'public',
  'message_translations',
  'source_lang',
  'translation cache stores the detected source language'
);

select col_not_null(
  'public',
  'message_translations',
  'source_lang',
  'cached source language is required'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.message_translations'::regclass
      and conname = 'message_translations_source_lang_check'
      and contype = 'c'
  ),
  'detected source language is constrained to supported languages'
);

select * from finish();
rollback;
