begin;

select plan(3);

update public.profiles
set primary_known_language = 'en', interface_language = 'en'
where id in (
  '00000000-0000-4000-8000-00000000000a',
  '00000000-0000-4000-8000-00000000000b'
);

insert into public.chats (id)
values ('5c000000-0000-4000-8000-000000000001');

insert into public.chat_members (chat_id, user_id, learning_language, mode)
values
  (
    '5c000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'en',
    'practice'
  ),
  (
    '5c000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000b',
    'de',
    'practice'
  );

insert into public.messages (id, chat_id, sender_id, body, created_at)
values
  (
    '5c000000-0000-4000-8000-000000000002',
    '5c000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'I am speaking English',
    now() + interval '1 second'
  ),
  (
    '5c000000-0000-4000-8000-000000000003',
    '5c000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'No',
    now() + interval '2 seconds'
  );

insert into public.message_translations (
  message_id, target_lang, translation_text, tokens, source_lang,
  source_hash, interface_lang, aid_mode, interface_text,
  cache_contract_version
) values (
  '5c000000-0000-4000-8000-000000000002',
  'de',
  'Ich spreche Englisch',
  '[]'::jsonb,
  'en',
  encode(
    digest(convert_to('I am speaking English', 'UTF8'), 'sha256'),
    'hex'
  ),
  'en',
  'translation',
  'I am speaking English',
  'automatic-forms-v2'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000b","role":"authenticated"}',
  true
);
set local role authenticated;

create temp table direct_prepared as
select public.request_message_translation(
  '5c000000-0000-4000-8000-000000000003'
) as value;
grant select on direct_prepared to authenticated;

select is(
  (select value ->> 'status' from direct_prepared),
  'ready',
  'interactive translation preparation remains ready'
);

select is(
  (select value #>> '{formContext,authorPrimaryKnownLanguage}'
   from direct_prepared),
  'en',
  'interactive preparation supplies the author primary known language'
);

select is(
  (select value #>> '{context,0,sourceLang}' from direct_prepared),
  'en',
  'interactive preparation supplies a prior cached source language'
);

reset role;
select * from finish();
rollback;
