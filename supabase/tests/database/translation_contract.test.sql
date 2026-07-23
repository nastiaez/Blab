begin;

select plan(10);

select has_column(
  'public',
  'message_translations',
  'interface_text',
  'translation cache stores the interface-language lane'
);

select col_not_null(
  'public',
  'message_translations',
  'interface_text',
  'cached interface-language text is required'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.message_translations'::regclass
      and conname = 'message_translations_interface_text_check'
  ),
  'cached interface-language text cannot be blank'
);

select has_column(
  'public',
  'message_translations',
  'interface_lang',
  'translation cache records the interface language'
);

select col_not_null(
  'public',
  'message_translations',
  'interface_lang',
  'cached interface language is required'
);

select ok(
  exists (
    select 1 from pg_constraint
    where conrelid = 'public.message_translations'::regclass
      and conname = 'message_translations_interface_lang_check'
      and contype = 'c'
  ),
  'interface language is constrained to launch locales'
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
  'detected source language is constrained to known codes or other'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.message_translations'::regclass
      and conname = 'message_translations_source_lang_check'
      and pg_get_constraintdef(oid) like '%other%'
  ),
  'arbitrary authored languages use the other source marker'
);

select * from finish();
rollback;
