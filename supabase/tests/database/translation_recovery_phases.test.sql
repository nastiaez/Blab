begin;

select plan(10);

delete from public.message_preparation_jobs;

update public.profiles
set primary_known_language = 'en'
where id = '00000000-0000-4000-8000-00000000000a';

insert into public.chats (id)
values ('5c000000-0000-4000-8000-000000000001');

insert into public.chat_members (
  chat_id,
  user_id,
  learning_language,
  mode
) values
  (
    '5c000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'de',
    'practice'
  ),
  (
    '5c000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000c',
    'es',
    'practice'
  );

insert into public.messages (id, chat_id, sender_id, body, created_at)
values
  (
    '5c000000-0000-4000-8000-000000000002',
    '5c000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'Oldest first',
    now() - interval '2 seconds'
  ),
  (
    '5c000000-0000-4000-8000-000000000003',
    '5c000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'Second message',
    now() - interval '1 second'
  );


update message_preparation_jobs set phase='word_help' where message_id='5c000000-0000-4000-8000-000000000003';
insert into messages(id,chat_id,sender_id,body) select gen_random_uuid(),'5c000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000a','Burst '||n from generate_series(1,4) n;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
create temp table claims as select * from claim_message_preparation_jobs_for_worker(20);
select is((select count(*) from claims where phase='sentence'),8::bigint,'sentence phase is capped at eight');
select is((select count(*) from claims where phase='word_help' limit 1),2::bigint,'word help cannot occupy sentence capacity');
select is((select count(*) from claims),10::bigint,'total concurrent leases bounded at ten');
select ok((select bool_and(lease_token is not null) from claims),'claims receive fencing tokens');
select is(leased_translation_action((select id from claims limit 1),gen_random_uuid(),'finish','{"outcome":"failed"}'), 'false'::jsonb,'unknown worker token cannot finish work');
select is(leased_translation_action((select id from claims limit 1),gen_random_uuid(),'prepare')->>'status','stale','unknown token cannot prepare work');
update message_preparation_jobs set locked_at=now()-interval '46 seconds' where id=(select id from claims where phase='sentence' limit 1);
create temp table reclaimed as select * from claim_message_preparation_jobs_for_worker(20);
select ok((select c.lease_token<>r.lease_token from claims c join reclaimed r using(id) limit 1),'expired work gets a new token');
select is(leased_translation_action((select c.id from claims c join reclaimed r using(id) limit 1),(select c.lease_token from claims c join reclaimed r using(id) limit 1),'finish','{"outcome":"failed"}'), 'false'::jsonb,'late old worker cannot overwrite reclaimed work');
select ok(not has_function_privilege('authenticated','leased_translation_action(uuid,uuid,text,jsonb)','execute'),'clients cannot impersonate recovery workers');
select is(leased_translation_action((select id from claims where phase='word_help' limit 1),(select lease_token from claims where phase='word_help' limit 1),'finish','{"outcome":"retry","reason":"http_429","delaySeconds":600}'), 'true'::jsonb,'long provider backoff accepted');
select * from finish();
rollback;
