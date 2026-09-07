begin;

select plan(4);

insert into public.chats (id)
values ('5b000000-0000-4000-8000-000000000001');

insert into public.chat_members (
  chat_id,
  user_id,
  learning_language,
  joined_at,
  mode
) values
  (
    '5b000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'ta',
    now() - interval '1 hour',
    'practice'
  ),
  (
    '5b000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000b',
    'de',
    now() - interval '1 hour',
    'practice'
  );

select is(
  (
    select count(*)
    from public.chat_language_timeline
    where chat_id = '5b000000-0000-4000-8000-000000000001'
      and user_id = '00000000-0000-4000-8000-00000000000a'
      and revision = 1
  ),
  1::bigint,
  'a new chat membership records its first learning-language era'
);

select is(
  (
    select learning_language
    from public.chat_language_timeline
    where chat_id = '5b000000-0000-4000-8000-000000000001'
      and user_id = '00000000-0000-4000-8000-00000000000a'
      and revision = 1
  ),
  'ta',
  'the first era keeps the learning language selected at chat creation'
);

insert into public.messages (
  id,
  chat_id,
  sender_id,
  body,
  created_at
) values (
  '5b000000-0000-4000-8000-000000000002',
  '5b000000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-00000000000b',
  'Good morning, Alice!',
  now() - interval '30 minutes'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  public.set_learning_language(
    '5b000000-0000-4000-8000-000000000001',
    'fr'
  ),
  2::bigint,
  'the first language switch advances to era two'
);

select is(
  (
    select learning_language
    from public.resolve_message_learning_era(
      '5b000000-0000-4000-8000-000000000002',
      '00000000-0000-4000-8000-00000000000a'
    )
  ),
  'ta',
  'a message from before the switch remains in the first learning language'
);

reset role;
select * from finish();
rollback;
