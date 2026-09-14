begin;

select plan(8);

delete from public.message_preparation_jobs;

update public.profiles
set primary_known_language = 'en'
where id = '00000000-0000-4000-8000-00000000000a';

insert into public.chats (id)
values ('5b000000-0000-4000-8000-000000000001');

insert into public.chat_members (
  chat_id,
  user_id,
  learning_language,
  mode
) values
  (
    '5b000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'de',
    'practice'
  ),
  (
    '5b000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000c',
    'es',
    'practice'
  );

insert into public.messages (id, chat_id, sender_id, body, created_at)
values
  (
    '5b000000-0000-4000-8000-000000000002',
    '5b000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'Oldest first',
    now() - interval '2 seconds'
  ),
  (
    '5b000000-0000-4000-8000-000000000003',
    '5b000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'Second message',
    now() - interval '1 second'
  );

select set_config('request.jwt.claims', '{"role":"service_role"}', true);
set local role service_role;

create temp table claimed_jobs as
select * from public.claim_message_preparation_jobs_for_worker(2);
grant select on claimed_jobs to service_role;

select is(
  (select count(*) from claimed_jobs),
  2::bigint,
  'the worker claims a bounded batch'
);

select is(
  (select count(distinct message_id) from claimed_jobs),
  1::bigint,
  'both viewer variants of the oldest message are claimed first'
);

select is(
  (select min(message_id::text) from claimed_jobs),
  '5b000000-0000-4000-8000-000000000002',
  'claiming is oldest-message first'
);

select is(
  (select min(attempts) from claimed_jobs),
  1,
  'claiming records the first attempt'
);

select is(
  public.request_message_translation_job(
    (
      select id
      from claimed_jobs
      where viewer_id = '00000000-0000-4000-8000-00000000000c'
    )
  ) #>> '{formContext,authorPrimaryKnownLanguage}',
  'en',
  'translation preparation supplies the message author primary known language'
);

select ok(
  public.finish_message_preparation_job(
    (select id from claimed_jobs order by id limit 1),
    'retry',
    'provider_unreachable',
    10
  ),
  'a retryable failure returns one job to the queue'
);

select ok(
  public.finish_message_preparation_job(
    (select id from claimed_jobs order by id desc limit 1),
    'failed',
    'translation_not_allowed',
    0
  ),
  'a permanent failure becomes terminal independently'
);

insert into public.message_translations (
  message_id, target_lang, translation_text, tokens, source_lang,
  source_hash, interface_lang, aid_mode, interface_text,
  cache_contract_version
) values (
  '5b000000-0000-4000-8000-000000000002',
  'de',
  'Zuerst',
  '[]'::jsonb,
  'en',
  encode(digest(convert_to('Oldest first', 'UTF8'), 'sha256'), 'hex'),
  'en',
  'translation',
  'Oldest first',
  'automatic-forms-v2'
);

create temp table claimed_context_jobs as
select * from public.claim_message_preparation_jobs_for_worker(2);
grant select on claimed_context_jobs to service_role;

select is(
  public.request_message_translation_job(
    (
      select id
      from claimed_context_jobs
      where viewer_id = '00000000-0000-4000-8000-00000000000c'
    )
  ) #>> '{context,0,sourceLang}',
  'en',
  'translation preparation supplies a prior cached source language'
);

reset role;
select * from finish();
rollback;
