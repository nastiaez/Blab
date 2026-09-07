-- Cached learning lines without complete word metadata can only show the
-- tapped word. Remove those incomplete cache entries so the translation
-- service regenerates the word, romanization, and known-language gloss.
delete from public.message_translations mt
where mt.translation_text ~ '[[:alnum:]]'
  and (
    jsonb_array_length(mt.tokens) = 0
    or exists (
      select 1
      from jsonb_array_elements(mt.tokens) as token
      where token->>'isContent' = 'true'
        and (
          nullif(btrim(token->>'gloss'), '') is null
          or (
            mt.target_lang in ('ta', 'uk', 'hi')
            and nullif(btrim(token->>'roman'), '') is null
          )
        )
    )
  );
