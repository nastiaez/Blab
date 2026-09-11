begin;

select plan(5);

insert into public.chats (id)
values ('5a000000-0000-4000-8000-000000000001');

insert into public.chat_members (
  chat_id,
  user_id,
  learning_language,
  learning_language_revision,
  translation_cutoff_at,
  mode
) values
  (
    '5a000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'de',
    3,
    now() - interval '1 hour',
    'practice'
  ),
  (
    '5a000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000b',
    'es',
    1,
    null,
    'practice'
  );

delete from public.chat_language_timeline
where chat_id = '5a000000-0000-4000-8000-000000000001'
  and user_id = '00000000-0000-4000-8000-00000000000a';

insert into public.chat_language_timeline (
  chat_id,
  user_id,
  revision,
  learning_language,
  created_at
) values
  (
    '5a000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    1,
    'uk',
    now() - interval '4 days'
  ),
  (
    '5a000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    2,
    'en',
    now() - interval '2 days'
  ),
  (
    '5a000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    3,
    'de',
    now() - interval '1 hour'
  );

insert into public.messages (
  id,
  chat_id,
  sender_id,
  body,
  created_at
) values (
  '5a000000-0000-4000-8000-000000000002',
  '5a000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-00000000000b',
  'Guten Morgen',
  now() - interval '3 days'
);

update public.profiles
set known_languages = array['en'],
    primary_known_language = 'en',
    interface_language = 'en'
where id = '00000000-0000-4000-8000-00000000000a';

delete from public.translation_usage
where user_id = '00000000-0000-4000-8000-00000000000a';

create temp table historical_prepared (value jsonb not null);
grant select, insert on historical_prepared to authenticated, service_role;

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}',
  true
);
set local role authenticated;

insert into historical_prepared (value)
values (
  public.request_message_translation(
    '5a000000-0000-4000-8000-000000000002'
  )
);

select is(
  (select value ->> 'status' from historical_prepared),
  'ready',
  'a historical message remains eligible after later language changes'
);

select is(
  (select value ->> 'targetLang' from historical_prepared),
  'uk',
  'the target comes from the language era active when the message arrived'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"role":"service_role"}',
  true
);
set local role service_role;

select ok(
  public.complete_message_translation(
    '5a000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-00000000000a',
    'uk',
    'en',
    encode(digest(convert_to('Guten Morgen', 'UTF8'), 'sha256'), 'hex'),
    'Добрий ранок',
    'Good morning',
    'de',
    'translation',
    null,
    null,
    '[]'::jsonb,
    null,
    'automatic-forms-v2'
  ),
  'a historical era translation can be completed after the viewer switches again'
);

select is(
  public.complete_message_translation(
    '5a000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-00000000000a',
    'de',
    'en',
    encode(digest(convert_to('Guten Morgen', 'UTF8'), 'sha256'), 'hex'),
    'Guten Morgen',
    'Good morning',
    'de',
    'none',
    null,
    null,
    '[]'::jsonb,
    null,
    'automatic-forms-v2'
  ),
  false,
  'a result for the current language cannot replace an older message era'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  (
    select count(*)
    from public.message_translations
    where message_id = '5a000000-0000-4000-8000-000000000002'
      and target_lang = 'uk'
      and interface_lang = 'en'
  ),
  1::bigint,
  'the viewer can still read the saved translation for that historical era'
);

reset role;
select * from finish();
rollback;
