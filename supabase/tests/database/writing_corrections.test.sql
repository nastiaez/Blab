begin;

select plan(19);

select has_column(
  'public',
  'message_translations',
  'aid_mode',
  'learning-aid cache records translation, correction, or none'
);
select has_column(
  'public',
  'message_translations',
  'explanation',
  'corrections can store a short localized explanation'
);
select has_column(
  'public',
  'message_translations',
  'confidence',
  'corrections record uncertainty'
);
select hasnt_column(
  'public',
  'message_translations',
  'scope_user_id',
  'same-language learning aids are shared with eligible learners'
);
select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.message_translations'::regclass
      and conname = 'message_translations_aid_mode_check'
  ),
  'learning-aid mode is constrained'
);

update public.profiles
set interface_language = 'en'
where id in (
  '00000000-0000-4000-8000-00000000000a',
  '00000000-0000-4000-8000-00000000000c'
);

insert into public.chats (id)
values ('71000000-0000-4000-8000-000000000001');

insert into public.chat_members (chat_id, user_id, learning_language)
values
  (
    '71000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'de'
  ),
  (
    '71000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000c',
    'de'
  );

insert into public.messages (id, chat_id, sender_id, body)
values
  (
    '72000000-0000-4000-8000-000000000001',
    '71000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'Machen du'
  ),
  (
    '72000000-0000-4000-8000-000000000002',
    '71000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'Wie geht es dir?'
  );

create temp table correction_prepared (
  label text primary key,
  value jsonb not null
);
grant select, insert on correction_prepared to authenticated, service_role;

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated"}',
  true
);
set local role authenticated;

insert into correction_prepared values (
  'recipient-incorrect',
  public.request_message_translation(
    '72000000-0000-4000-8000-000000000001'
  )
);
select is(
  (select value ->> 'status' from correction_prepared
    where label = 'recipient-incorrect'),
  'ready',
  'the recipient can request same-language analysis'
);
select ok(
  not ((select value from correction_prepared
    where label = 'recipient-incorrect') ? 'allowCorrection'),
  'correction eligibility no longer depends on message ownership'
);

reset role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;

select ok(
  public.complete_message_translation(
    '72000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000c',
    'de',
    (select value ->> 'interfaceLang' from correction_prepared
      where label = 'recipient-incorrect'),
    (select value ->> 'sourceHash' from correction_prepared
      where label = 'recipient-incorrect'),
    'Machst du ...?',
    'What are you doing?',
    'de',
    'correction',
    'The verb must agree with du.',
    'medium',
    '[{"text":"Machst du","gloss":"do you","isContent":true},{"text":" ...?","isContent":false}]'::jsonb
  ),
  'a recipient request can complete a shared correction'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  (select count(*) from public.message_translations
    where message_id = '72000000-0000-4000-8000-000000000001'
      and aid_mode = 'correction'),
  1::bigint,
  'the recipient can read the shared correction'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  (select count(*) from public.message_translations
    where message_id = '72000000-0000-4000-8000-000000000001'
      and aid_mode = 'correction'),
  1::bigint,
  'the author can read the same correction'
);
select is(
  public.request_message_translation(
    '72000000-0000-4000-8000-000000000001'
  ) ->> 'status',
  'cached',
  'the author reuses the recipient-generated cache row'
);
select is(
  public.request_message_translation(
    '72000000-0000-4000-8000-000000000001'
  ) ->> 'mode',
  'correction',
  'the author receives correction mode'
);
select is(
  public.request_message_translation(
    '72000000-0000-4000-8000-000000000001'
  ) ->> 'translation',
  'Machst du ...?',
  'the corrected text is shared consistently'
);
select is(
  public.request_message_translation(
    '72000000-0000-4000-8000-000000000001'
  ) ->> 'interfaceText',
  'What are you doing?',
  'the corrected meaning supplies the interface-language lane'
);
select is(
  public.request_message_translation(
    '72000000-0000-4000-8000-000000000001'
  ) ->> 'explanation',
  'The verb must agree with du.',
  'the localized explanation is returned from cache'
);

reset role;
select is(
  (select count(*) from public.message_translations
    where message_id = '72000000-0000-4000-8000-000000000001'),
  1::bigint,
  'one shared cache row serves both eligible learners'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated"}',
  true
);
set local role authenticated;
insert into correction_prepared values (
  'recipient-correct',
  public.request_message_translation(
    '72000000-0000-4000-8000-000000000002'
  )
);
select is(
  (select value ->> 'status' from correction_prepared
    where label = 'recipient-correct'),
  'ready',
  'correct same-language text still receives one analysis'
);

reset role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;
select ok(
  public.complete_message_translation(
    '72000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-00000000000c',
    'de',
    (select value ->> 'interfaceLang' from correction_prepared
      where label = 'recipient-correct'),
    (select value ->> 'sourceHash' from correction_prepared
      where label = 'recipient-correct'),
    'Wie geht es dir?',
    'How are you?',
    'de',
    'none',
    null,
    null,
    '[]'::jsonb
  ),
  'correct writing stores a shared none result'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  public.request_message_translation(
    '72000000-0000-4000-8000-000000000002'
  ) ->> 'mode',
  'none',
  'correct target-language writing shows no learning line to either user'
);

select * from finish();
rollback;
