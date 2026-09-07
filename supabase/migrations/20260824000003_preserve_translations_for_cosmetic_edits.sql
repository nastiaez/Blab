-- FR-37: whitespace- and emoji-only edits do not change the language help.
-- Letters, numbers, and punctuation still invalidate every cached locale.

create or replace function public.translation_semantic_body(value text)
returns text
language sql
immutable
set search_path = public
as $$
  select regexp_replace(
    regexp_replace(coalesce(value, ''), '[[:space:]]', '', 'g'),
    '[☀-⿿🀀-🫿]',
    '',
    'g'
  );
$$;

revoke all on function public.translation_semantic_body(text)
  from public, anon, authenticated;

create or replace function public.invalidate_message_translations_on_edit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.translation_semantic_body(new.body)
      is distinct from public.translation_semantic_body(old.body) then
    delete from public.message_translations
    where message_id = new.id;
  end if;
  return null;
end;
$$;

revoke all on function public.invalidate_message_translations_on_edit()
  from public, anon, authenticated;
