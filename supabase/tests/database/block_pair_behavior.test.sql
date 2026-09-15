begin;

select plan(9);

delete from public.blocks
where blocker_id in (
  '00000000-0000-4000-8000-00000000000a',
  '00000000-0000-4000-8000-00000000000c'
)
and blocked_id in (
  '00000000-0000-4000-8000-00000000000a',
  '00000000-0000-4000-8000-00000000000c'
);

delete from public.chats
where member_low_id = '00000000-0000-4000-8000-00000000000a'
  and member_high_id = '00000000-0000-4000-8000-00000000000c';

insert into public.chats (id, member_low_id, member_high_id)
values (
  'b10c0000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-00000000000a',
  '00000000-0000-4000-8000-00000000000c'
);

insert into public.chat_members (chat_id, user_id, learning_language)
values
  (
    'b10c0000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'de'
  ),
  (
    'b10c0000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000c',
    'en'
  );

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}',
  true
);
set local role authenticated;

insert into public.blocks (blocker_id, blocked_id)
values (
  '00000000-0000-4000-8000-00000000000a',
  '00000000-0000-4000-8000-00000000000c'
);

select ok(
  public.is_blocked_in_chat('b10c0000-0000-4000-8000-000000000001'),
  'the blocker also sees the chat as blocked'
);

select throws_ok(
  $$
    insert into public.messages (chat_id, sender_id, body)
    values (
      'b10c0000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-00000000000a',
      'blocked sender attempt'
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "messages"',
  'the blocker cannot send while the block exists'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated"}',
  true
);
set local role authenticated;

select ok(
  public.is_blocked_in_chat('b10c0000-0000-4000-8000-000000000001'),
  'the blocked participant sees the chat as blocked'
);

select throws_ok(
  $$
    insert into public.messages (chat_id, sender_id, body)
    values (
      'b10c0000-0000-4000-8000-000000000001',
      '00000000-0000-4000-8000-00000000000c',
      'blocked recipient attempt'
    )
  $$,
  '42501',
  'new row violates row-level security policy for table "messages"',
  'the blocked participant cannot send while the block exists'
);

reset role;

insert into public.invites (token, inviter_user_id)
values ('blocked-pair-reconnect', '00000000-0000-4000-8000-00000000000a');

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated"}',
  true
);
set local role authenticated;

select results_eq(
  $$
    select chat_id, is_new_connection
    from public.claim_invite('blocked-pair-reconnect')
  $$,
  $$
    values (
      'b10c0000-0000-4000-8000-000000000001'::uuid,
      false
    )
  $$,
  'claiming another invite reuses the existing blocked chat'
);

select ok(
  public.is_blocked_in_chat('b10c0000-0000-4000-8000-000000000001'),
  'claiming another invite preserves the block'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}',
  true
);
set local role authenticated;

delete from public.blocks
where blocker_id = auth.uid()
  and blocked_id = '00000000-0000-4000-8000-00000000000c';

select is(
  public.is_blocked_in_chat('b10c0000-0000-4000-8000-000000000001'),
  false,
  'unblocking restores the chat for the former blocker'
);

insert into public.messages (chat_id, sender_id, body)
values (
  'b10c0000-0000-4000-8000-000000000001',
  '00000000-0000-4000-8000-00000000000a',
  'sending restored'
);

select is(
  (
    select count(*)
    from public.messages
    where chat_id = 'b10c0000-0000-4000-8000-000000000001'
  ),
  1::bigint,
  'unblocking restores message inserts'
);

reset role;
select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  public.is_blocked_in_chat('b10c0000-0000-4000-8000-000000000001'),
  false,
  'unblocking restores the chat for the other participant'
);

reset role;
select * from finish();
rollback;
