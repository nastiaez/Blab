begin;

select plan(24);

select has_table(
  'public',
  'translation_usage',
  'durable translation quota state exists'
);

select has_column(
  'public',
  'message_translations',
  'source_hash',
  'cache records the authoritative source version'
);

select ok(
  exists (
    select 1
    from pg_constraint
    where conrelid = 'public.message_translations'::regclass
      and conname = 'message_translations_source_hash_check'
  ),
  'cache source hashes are constrained'
);

select ok(
  not has_table_privilege('authenticated', 'public.message_translations', 'insert'),
  'authenticated clients cannot insert shared translations'
);

select ok(
  has_table_privilege('authenticated', 'public.message_translations', 'select'),
  'authenticated clients retain authorized cache reads'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.request_message_translation(uuid)',
    'execute'
  ),
  'authenticated users can request authorized preparation'
);

select ok(
  not has_function_privilege(
    'anon',
    'public.request_message_translation(uuid)',
    'execute'
  ),
  'anonymous users cannot prepare translations'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.complete_message_translation(uuid,uuid,text,text,text,text,text,text,text,text,text,jsonb)',
    'execute'
  ),
  'authenticated users cannot complete cache writes'
);

insert into public.chats (id)
values ('51000000-0000-4000-8000-000000000001');

insert into public.chat_members (chat_id, user_id, learning_language)
values
  ('51000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-00000000000a', 'de'),
  ('51000000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-00000000000b', 'fr');

insert into public.messages (
  id,
  chat_id,
  sender_id,
  body,
  created_at,
  deleted_at
) values
  (
    '52000000-0000-4000-8000-000000000001',
    '51000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'Hello current',
    now(),
    null
  ),
  (
    '52000000-0000-4000-8000-000000000002',
    '51000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000b',
    'Edit race source',
    now(),
    null
  ),
  (
    '52000000-0000-4000-8000-000000000003',
    '51000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'Old translation era',
    now() - interval '2 days',
    null
  ),
  (
    '52000000-0000-4000-8000-000000000004',
    '51000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'Deleted source',
    now(),
    now()
  ),
  (
    '52000000-0000-4000-8000-000000000005',
    '51000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'Talking about mum',
    now() + interval '1 minute',
    null
  ),
  (
    '52000000-0000-4000-8000-000000000007',
    '51000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000b',
    '😂',
    now() + interval '1 minute 30 seconds',
    null
  ),
  (
    '52000000-0000-4000-8000-000000000006',
    '51000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000b',
    'Short implied subject',
    now() + interval '2 minutes',
    null
  );

update public.chat_members
set translation_cutoff_at = now() - interval '1 day'
where chat_id = '51000000-0000-4000-8000-000000000001'
  and user_id = '00000000-0000-4000-8000-00000000000a';

create temp table l13_prepared (
  label text primary key,
  value jsonb not null
);
grant select, insert on table l13_prepared to authenticated, service_role;

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}',
  true
);
set local role authenticated;

insert into l13_prepared (label, value)
values (
  'current',
  public.request_message_translation(
    '52000000-0000-4000-8000-000000000001'
  )
);

select is(
  (select value ->> 'status' from l13_prepared where label = 'current'),
  'ready',
  'an active chat member can prepare a current message'
);

select is(
  (select value ->> 'targetLang' from l13_prepared where label = 'current'),
  'de',
  'target language comes from the caller membership row'
);

insert into l13_prepared (label, value)
values (
  'with-context',
  public.request_message_translation(
    '52000000-0000-4000-8000-000000000006'
  )
);

select is(
  jsonb_array_length(
    (select value -> 'context' from l13_prepared where label = 'with-context')
  ),
  3,
  'a cache miss includes recent same-chat context'
);

select is(
  (
    select value #>> '{context,2,text}'
    from l13_prepared
    where label = 'with-context'
  ),
  'Talking about mum',
  'context is ordered oldest to newest before the current message'
);

reset role;

select is(
  (
    select minute_requests
    from public.translation_usage
    where user_id = '00000000-0000-4000-8000-00000000000a'
  ),
  2,
  'cache misses reserve quota requests'
);

select set_config(
  'request.jwt.claims',
  '{"role":"service_role"}',
  true
);
set local role service_role;

select ok(
  public.complete_message_translation(
    '52000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'de',
    (select value ->> 'interfaceLang' from l13_prepared where label = 'current'),
    (select value ->> 'sourceHash' from l13_prepared where label = 'current'),
    'Hallo aktuell',
    'Hello current',
    'en',
    'translation',
    null,
    null,
    '[{"text":"Hallo aktuell","gloss":"Hello current","isContent":true}]'::jsonb
  ),
  'service role can complete an unchanged authorized translation'
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
    '52000000-0000-4000-8000-000000000001'
  ) ->> 'status',
  'cached',
  'a completed translation is returned from cache'
);

reset role;

select is(
  (
    select minute_requests
    from public.translation_usage
    where user_id = '00000000-0000-4000-8000-00000000000a'
  ),
  2,
  'a cache hit consumes no additional quota'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  public.request_message_translation(
    '52000000-0000-4000-8000-000000000001'
  ) ->> 'status',
  'forbidden',
  'a non-member cannot prepare another chat message'
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
    '52000000-0000-4000-8000-000000000003'
  ) ->> 'status',
  'not_eligible',
  'messages before the caller translation cutoff are not eligible'
);

select is(
  public.request_message_translation(
    '52000000-0000-4000-8000-000000000004'
  ) ->> 'status',
  'forbidden',
  'deleted messages cannot be translated'
);

select is(
  public.request_message_translation(
    '52000000-0000-4000-8000-000000000099'
  ) ->> 'status',
  'forbidden',
  'nonexistent messages cannot be translated'
);

insert into l13_prepared (label, value)
values (
  'stale',
  public.request_message_translation(
    '52000000-0000-4000-8000-000000000002'
  )
);

reset role;
update public.messages
set body = 'Edited after preparation'
where id = '52000000-0000-4000-8000-000000000002';

select set_config(
  'request.jwt.claims',
  '{"role":"service_role"}',
  true
);
set local role service_role;

select is(
  public.complete_message_translation(
    '52000000-0000-4000-8000-000000000002',
    '00000000-0000-4000-8000-00000000000a',
    'de',
    (select value ->> 'interfaceLang' from l13_prepared where label = 'stale'),
    (select value ->> 'sourceHash' from l13_prepared where label = 'stale'),
    'Veraltete Uebersetzung',
    'Edit race source',
    'en',
    'translation',
    null,
    null,
    '[]'::jsonb
  ),
  false,
  'completion rejects a source that changed after preparation'
);

reset role;
update public.translation_usage
set minute_started_at = date_trunc('minute', now()),
    minute_requests = 60,
    day_started_at = (now() at time zone 'utc')::date,
    day_requests = 2,
    day_characters = 30
where user_id = '00000000-0000-4000-8000-00000000000a';

select set_config(
  'request.jwt.claims',
  '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  public.request_message_translation(
    '52000000-0000-4000-8000-000000000002'
  ) ->> 'status',
  'rate_limited',
  'the minute request limit rejects additional provider work'
);

reset role;
update public.translation_usage
set minute_requests = 0,
    day_requests = 200
where user_id = '00000000-0000-4000-8000-00000000000a';

set local role authenticated;

select is(
  public.request_message_translation(
    '52000000-0000-4000-8000-000000000002'
  ) ->> 'status',
  'rate_limited',
  'the daily request limit rejects additional provider work'
);

reset role;

select is(
  (
    select count(*)
    from public.message_translations
    where message_id = '52000000-0000-4000-8000-000000000002'
  ),
  0::bigint,
  'a rejected stale completion leaves no cache row'
);

select * from finish();
rollback;
