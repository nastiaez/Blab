begin;

select plan(14);

insert into public.chats (id, created_at)
values
  ('41000000-0000-4000-8000-000000000001', now() - interval '2 days'),
  ('41000000-0000-4000-8000-000000000002', now() - interval '1 day');

insert into public.chat_members (chat_id, user_id, learning_language)
values
  ('41000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-00000000000a', 'de'),
  ('41000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-00000000000b', 'fr'),
  ('41000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-00000000000a', 'es'),
  ('41000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-00000000000b', 'it');

insert into public.messages (id, chat_id, sender_id, body, created_at, reply_to)
values
  ('42000000-0000-4000-8000-000000000001', '41000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-00000000000a', 'canonical history', now() - interval '2 days', null),
  ('42000000-0000-4000-8000-000000000002', '41000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-00000000000b', 'duplicate history', now() - interval '1 day', null),
  ('42000000-0000-4000-8000-000000000003', '41000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-00000000000a', 'reply history', now() - interval '23 hours', '42000000-0000-4000-8000-000000000002');

insert into public.message_reads (message_id, user_id, chat_id)
values (
  '42000000-0000-4000-8000-000000000002',
  '00000000-0000-4000-8000-00000000000a',
  '41000000-0000-4000-8000-000000000002'
);

insert into public.message_translations (
  message_id, target_lang, translation_text
) values (
  '42000000-0000-4000-8000-000000000002', 'de', 'Duplikatverlauf'
);

insert into public.invites (
  token,
  inviter_user_id,
  inviter_learning_language,
  used_at,
  used_by_user_id,
  resulting_chat_id
) values (
  'l11fixture01',
  '00000000-0000-4000-8000-00000000000a',
  'es',
  now(),
  '00000000-0000-4000-8000-00000000000b',
  '41000000-0000-4000-8000-000000000002'
);

insert into public.reports (
  reporter_id,
  reported_user_id,
  chat_id,
  message_id,
  reason,
  target_type
) values (
  '00000000-0000-4000-8000-00000000000a',
  '00000000-0000-4000-8000-00000000000b',
  '41000000-0000-4000-8000-000000000002',
  '42000000-0000-4000-8000-000000000002',
  'spam',
  'message'
);

select is(
  public.consolidate_duplicate_pair_chats(),
  1,
  'one duplicate chat is consolidated'
);

select is(
  (select count(*) from public.chats where id = '41000000-0000-4000-8000-000000000002'),
  0::bigint,
  'newer duplicate chat is removed'
);

select is(
  (select count(*) from public.messages where chat_id = '41000000-0000-4000-8000-000000000001'),
  3::bigint,
  'all message history moves to the oldest chat'
);

select is(
  (select reply_to::text from public.messages where id = '42000000-0000-4000-8000-000000000003'),
  '42000000-0000-4000-8000-000000000002',
  'reply identity survives consolidation'
);

select is(
  (select chat_id::text from public.message_reads where message_id = '42000000-0000-4000-8000-000000000002'),
  '41000000-0000-4000-8000-000000000001',
  'read receipts point to the canonical chat'
);

select is(
  (select count(*) from public.message_translations where message_id = '42000000-0000-4000-8000-000000000002'),
  1::bigint,
  'message translations remain attached'
);

select is(
  (select resulting_chat_id::text from public.invites where token = 'l11fixture01'),
  '41000000-0000-4000-8000-000000000001',
  'used invites point to the canonical chat'
);

select is(
  (select chat_id::text from public.reports where message_id = '42000000-0000-4000-8000-000000000002'),
  '41000000-0000-4000-8000-000000000001',
  'moderation references point to the canonical chat'
);

select is(
  (select learning_language from public.chat_members where chat_id = '41000000-0000-4000-8000-000000000001' and user_id = '00000000-0000-4000-8000-00000000000a'),
  'es',
  'latest Alice language is retained'
);

select is(
  (select learning_language from public.chat_members where chat_id = '41000000-0000-4000-8000-000000000001' and user_id = '00000000-0000-4000-8000-00000000000b'),
  'it',
  'latest Bob language is retained'
);

select is(
  (select member_low_id::text from public.chats where id = '41000000-0000-4000-8000-000000000001'),
  '00000000-0000-4000-8000-00000000000a',
  'canonical chat stores the lower participant id'
);

select is(
  (select member_high_id::text from public.chats where id = '41000000-0000-4000-8000-000000000001'),
  '00000000-0000-4000-8000-00000000000b',
  'canonical chat stores the higher participant id'
);

select is(
  (select translation_cutoff_at from public.chat_members where chat_id = '41000000-0000-4000-8000-000000000001' and user_id = '00000000-0000-4000-8000-00000000000a'),
  (select created_at from public.chats where id = '41000000-0000-4000-8000-000000000001') + interval '1 day',
  'Alice translation cutoff starts at the newer language era'
);

select is(
  (select translation_cutoff_at from public.chat_members where chat_id = '41000000-0000-4000-8000-000000000001' and user_id = '00000000-0000-4000-8000-00000000000b'),
  (select created_at from public.chats where id = '41000000-0000-4000-8000-000000000001') + interval '1 day',
  'Bob translation cutoff starts at the newer language era'
);

select * from finish();
rollback;
