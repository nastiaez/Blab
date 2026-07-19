-- Rebuild rows where the provider copied a learning-language line into a
-- different interface-language lane instead of translating it.
-- The cache is disposable; messages remain untouched.
delete from public.message_translations
where target_lang <> interface_lang
  and lower(btrim(interface_text)) = lower(btrim(translation_text));
