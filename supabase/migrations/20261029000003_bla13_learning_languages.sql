-- BLA-13: extend learning/source languages without adding interface locales.
-- Preserve function bodies, signatures, grants, RLS and existing cache records.
-- Some current wrappers call renamed older implementations; update those too.
begin;
alter table public.message_translations
  drop constraint message_translations_source_lang_check,
  add constraint message_translations_source_lang_check check (
    source_lang in ('en','nl','fr','de','hi','it','pt','es','ta','tr','uk','da','fi','ko','mr','pl','other')),
  drop constraint message_translations_interface_lang_check,
  add constraint message_translations_interface_lang_check check (
    interface_lang in ('en','nl','fr','de','hi','it','pt','es','ta','tr','uk','da','fi','ko','mr','pl'));

-- Match ONLY the complete previous learning-language allowlist, in its two
-- historical orders. Never modify the separate four-locale interface list.
do $migration$
declare
  f record;
  original text;
  updated text;
  old_list text;
  pattern text;
begin
  for f in select p.oid from pg_proc p join pg_namespace n on n.oid=p.pronamespace
           where n.nspname='public' and p.prokind='f'
  loop
    original := pg_get_functiondef(f.oid);
    updated := original;
    foreach old_list in array array[
      '''nl'',''en'',''fr'',''de'',''hi'',''it'',''pt'',''es'',''ta'',''tr'',''uk''',
      '''en'',''nl'',''fr'',''de'',''hi'',''it'',''pt'',''es'',''ta'',''tr'',''uk'''
    ] loop
      pattern := replace(old_list, ',', ',[[:space:]]*');
      updated := regexp_replace(updated, pattern,
        old_list || ',''da'',''fi'',''ko'',''mr'',''pl''', 'g');
    end loop;
    if updated <> original then execute updated; end if;
  end loop;
end
$migration$;
commit;
