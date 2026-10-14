begin;
select plan(11);
insert into chats(id) values('6d000000-0000-4000-8000-000000000001');
insert into chat_members(chat_id,user_id,learning_language) values
('6d000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000a','de'),
('6d000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000b','en');
create temp table inbox_fixture as select jsonb_build_object('type','message.new','cid','blab:6d000000-0000-4000-8000-000000000001','created_at',now(),'message',jsonb_build_object('id','6d000000-0000-4000-8000-000000000002')) as event;
grant select on inbox_fixture to service_role;
select ok(not has_table_privilege('authenticated','stream_event_inbox','select'),'private queue cannot expose event identities');
select ok(not has_function_privilege('authenticated','enqueue_stream_message_event(text,text,jsonb)','execute'),'clients cannot forge vendor events');
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select is(enqueue_stream_message_event('event-one',repeat('a',64),(select event from inbox_fixture)),'ignored_unmigrated','existing chat remains Supabase-owned');
insert into chat_message_transports(chat_id,provider,migration_state) values('6d000000-0000-4000-8000-000000000001','stream','active');
select is(enqueue_stream_message_event('event-one',repeat('a',64),(select event from inbox_fixture)),'queued','migrated event durably queued');
select is(enqueue_stream_message_event('event-one',repeat('a',64),(select event from inbox_fixture)),'duplicate','same delivery is idempotent');
select is(enqueue_stream_message_event('event-two',repeat('a',64),(select event from inbox_fixture)),'duplicate','new unsigned header cannot replay identical signed body');
select throws_ok($$select enqueue_stream_message_event('event-one',repeat('b',64),(select event from inbox_fixture))$$,'P0001','stream_event_identity_conflict','event identity cannot be reused for a different body');
create temp table inbox_claim as select * from claim_stream_message_events(1);
grant select on inbox_claim to service_role;
select is((select count(*) from inbox_claim),1::bigint,'only one nonduplicate task claimed');
select ok(not finish_stream_message_event('event-one','00000000-0000-4000-8000-000000000001',true),'stale worker cannot finish current lease');
select ok(finish_stream_message_event('event-one',(select lease_token from inbox_claim),false,'fixture_retry'),'current worker may schedule retry');
select ok((select status='pending' and next_attempt_at>now() and lease_token is null from stream_event_inbox where event_id='event-one'),'retry is bounded and releases old lease');
reset role;
select * from finish();
rollback;
