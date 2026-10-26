begin;
select plan(13);
insert into chats(id) values ('6c000000-0000-4000-8000-000000000001');
insert into chat_members(chat_id,user_id,learning_language,mode) values
('6c000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000a','de','practice'),
('6c000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000b','en','practice');
insert into messages(id,chat_id,sender_id,body,created_at) values
('6c000000-0000-4000-8000-000000000002','6c000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000b','Older question',now()+interval '1 second'),
('6c000000-0000-4000-8000-000000000003','6c000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000a','Previous one',now()+interval '2 seconds'),
('6c000000-0000-4000-8000-000000000004','6c000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000a','Previous two',now()+interval '3 seconds'),
('6c000000-0000-4000-8000-000000000005','6c000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000b','!!! 😊',now()+interval '4 seconds'),
('6c000000-0000-4000-8000-000000000006','6c000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000b','Yes tomorrow',now()+interval '5 seconds'),
('6c000000-0000-4000-8000-000000000007','6c000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000a','Future excluded',now()+interval '6 seconds');
select is(jsonb_array_length(translation_recent_context('6c000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-00000000000a',null)),2,'two meaningful prior lines, not punctuation or future messages');
select is(translation_recent_context('6c000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-00000000000a',null)#>>'{0,text}','Previous one','oldest-to-newest order');
select is(translation_recent_context('6c000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-00000000000a',null)#>>'{1,speaker}','viewer','both recent messages may have the same author');
update messages set reply_to='6c000000-0000-4000-8000-000000000002' where id='6c000000-0000-4000-8000-000000000006';
select is(jsonb_array_length(translation_recent_context('6c000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-00000000000a',null)),3,'explicit older quote adds one context line');
select is(translation_recent_context('6c000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-00000000000a',null)#>>'{0,isReply}','true','quoted source is marked as reply context');
update messages set reply_to='6c000000-0000-4000-8000-000000000004' where id='6c000000-0000-4000-8000-000000000006';
select is(jsonb_array_length(translation_recent_context('6c000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-00000000000a',null)),2,'quote already among two is not duplicated');
update messages set reply_to='6c000000-0000-4000-8000-000000000002' where id='6c000000-0000-4000-8000-000000000006';
select is(translation_recent_context('6c000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-00000000000a',now()+interval '3 seconds')#>>'{0,text}','Older question','authorized explicit quote survives language-era boundary');
update messages set deleted_at=now() where id='6c000000-0000-4000-8000-000000000002';
select is(jsonb_array_length(translation_recent_context('6c000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-00000000000a',null)),2,'deleted quote is excluded');
select is(jsonb_array_length(translation_recent_context('6c000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-00000000000a',now()+interval '3 seconds')),1,'language-era boundary remains intact');
select is(translation_recent_context('6c000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-00000000000c',null),'[]'::jsonb,'nonmember context is empty');
select ok(not has_function_privilege('authenticated','translation_recent_context(uuid,uuid,timestamptz)','execute'),'caller cannot impersonate another viewer through helper');
-- Isolate the interactive owner from automatically queued fixture work.
delete from message_preparation_jobs where chat_id='6c000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}',true);
set local role authenticated;
select is(jsonb_array_length(request_message_translation('6c000000-0000-4000-8000-000000000006')->'context'),2,'interactive authorized path uses the bounded context');
reset role;
-- Restore the independent background-owner scenario after the interactive case.
select enqueue_message_preparation_jobs('6c000000-0000-4000-8000-000000000006');
update message_preparation_jobs set status='processing',locked_at=now() where message_id='6c000000-0000-4000-8000-000000000006' and viewer_id='00000000-0000-4000-8000-00000000000a';
create temp table context_worker_job as select id from message_preparation_jobs where message_id='6c000000-0000-4000-8000-000000000006' and viewer_id='00000000-0000-4000-8000-00000000000a';
grant select on context_worker_job to service_role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select is(jsonb_array_length(request_message_translation_job((select id from context_worker_job))->'context'),2,'background worker uses the same bounded context');
reset role;
select * from finish();
rollback;
