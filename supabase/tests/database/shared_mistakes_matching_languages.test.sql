begin;

select plan(6);

select has_column(
  'public',
  'messages',
  'languages_matched_at_send',
  'messages store the send-time learning-language match'
);

select col_not_null(
  'public',
  'messages',
  'languages_matched_at_send',
  'send-time learning-language match is always decided'
);

insert into public.chats (id)
values ('73000000-0000-4000-8000-000000000000');

insert into public.chat_members (chat_id, user_id, learning_language)
values
  (
    '73000000-0000-4000-8000-000000000000',
    '00000000-0000-4000-8000-00000000000a',
    'de'
  ),
  (
    '73000000-0000-4000-8000-000000000000',
    '00000000-0000-4000-8000-00000000000c',
    'de'
  );

insert into public.messages (
  id,
  chat_id,
  sender_id,
  body,
  created_at,
  languages_matched_at_send
) values (
  '73000000-0000-4000-8000-000000000001',
  '73000000-0000-4000-8000-000000000000',
  '00000000-0000-4000-8000-00000000000a',
  'Machen du?',
  '2026-09-30 07:00:01+00',
  false
);

update public.chat_members
set learning_language = 'es'
where chat_id = '73000000-0000-4000-8000-000000000000'
  and user_id = '00000000-0000-4000-8000-00000000000c';

insert into public.messages (
  id,
  chat_id,
  sender_id,
  body,
  created_at,
  languages_matched_at_send
) values (
  '73000000-0000-4000-8000-000000000002',
  '73000000-0000-4000-8000-000000000000',
  '00000000-0000-4000-8000-00000000000a',
  'Machen du?',
  '2026-09-30 07:00:02+00',
  true
);

update public.chat_members
set learning_language = 'de'
where chat_id = '73000000-0000-4000-8000-000000000000'
  and user_id = '00000000-0000-4000-8000-00000000000c';

insert into public.messages (
  id,
  chat_id,
  sender_id,
  body,
  created_at
) values (
  '73000000-0000-4000-8000-000000000003',
  '73000000-0000-4000-8000-000000000000',
  '00000000-0000-4000-8000-00000000000a',
  'Machen du?',
  '2026-09-30 07:00:03+00'
);

select results_eq(
  $$
    select languages_matched_at_send
    from public.messages
    where id in (
      '73000000-0000-4000-8000-000000000001',
      '73000000-0000-4000-8000-000000000002',
      '73000000-0000-4000-8000-000000000003'
    )
    order by created_at, id
  $$,
  array[true, false, true],
  'eligibility follows the language match at each message insert'
);

select is(
  (
    select languages_matched_at_send
    from public.messages
    where id = '73000000-0000-4000-8000-000000000002'
  ),
  false,
  'the database ignores a forged matching-language value'
);

update public.messages
set body = 'Machst du?'
where id = '73000000-0000-4000-8000-000000000001';

select is(
  (
    select languages_matched_at_send
    from public.messages
    where id = '73000000-0000-4000-8000-000000000001'
  ),
  true,
  'editing a message preserves its original eligibility'
);

insert into public.messages (
  id,
  chat_id,
  sender_id,
  body,
  languages_matched_at_send
) values (
  '73000000-0000-4000-8000-000000000001',
  '73000000-0000-4000-8000-000000000000',
  '00000000-0000-4000-8000-00000000000a',
  'Duplicate resend',
  false
)
on conflict (id) do nothing;

select is(
  (
    select languages_matched_at_send
    from public.messages
    where id = '73000000-0000-4000-8000-000000000001'
  ),
  true,
  'an idempotent resend preserves the first eligibility decision'
);

select * from finish();
rollback;
