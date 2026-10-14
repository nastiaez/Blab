begin;
select plan(17);
insert into chats(id) values('74000000-0000-4000-8000-000000000001');
insert into chat_members(chat_id,user_id,learning_language) values
('74000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000a','de'),
('74000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000b','en');
insert into chat_message_transports(chat_id,provider,migration_state) values('74000000-0000-4000-8000-000000000001','stream','active');
create temp table activity_fixture as select jsonb_build_object('id','74000000-0000-4000-8000-000000000002','cid','blab:74000000-0000-4000-8000-000000000001','user',jsonb_build_object('id','00000000-0000-4000-8000-00000000000a'),'type','regular','text','Hello','created_at',now(),'updated_at',now(),'attachments','[]'::jsonb,
'blab_read_by',jsonb_build_array('00000000-0000-4000-8000-00000000000a','00000000-0000-4000-8000-00000000000b'),
'latest_reactions',jsonb_build_array(jsonb_build_object('type','blab_fixture','blab_emoji','❤️','user_id','00000000-0000-4000-8000-00000000000b'))) as value;
grant select on activity_fixture to service_role;
-- Test-only observation; runtime writes go through the definer RPC.
grant select on message_reactions to service_role;
select ok(not has_function_privilege('authenticated','apply_stream_message_activity(uuid,jsonb,timestamptz)','execute'),'only server may update derived activity');
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select is(apply_stream_message_snapshot('74000000-0000-4000-8000-000000000001',(select value from activity_fixture)),'applied','canonical source established');
select is(apply_stream_message_activity('74000000-0000-4000-8000-000000000001',(select value from activity_fixture),now()),'applied','canonical read and emoji applied');
select is((select count(*) from message_reads where message_id='74000000-0000-4000-8000-000000000002'),1::bigint,'only actual recipient contributes receipt');
select is((select count(*) from message_reads where message_id='74000000-0000-4000-8000-000000000002' and user_id='00000000-0000-4000-8000-00000000000a'),0::bigint,'authored read cannot forge partner receipt');
select is((select emoji from message_reactions where message_id='74000000-0000-4000-8000-000000000002'),'❤️','canonical Unicode emoji preserved');
select is(apply_stream_message_activity('74000000-0000-4000-8000-000000000001',(select value||'{"latest_reactions":[]}'::jsonb from activity_fixture),now()-interval '1 second'),'stale','late metadata cannot reverse current state');
select is((select emoji from message_reactions where message_id='74000000-0000-4000-8000-000000000002'),'❤️','stale empty reaction does not erase latest emoji');
select is(apply_stream_message_activity('74000000-0000-4000-8000-000000000001',(select value||'{"latest_reactions":[]}'::jsonb from activity_fixture),now()+interval '1 second'),'applied','newer emoji removal accepted');
select is((select count(*) from message_reactions where message_id='74000000-0000-4000-8000-000000000002'),0::bigint,'removed reaction is absent');
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000000b","role":"authenticated"}',true);
set local role authenticated;
select is(authorize_stream_activity('74000000-0000-4000-8000-000000000001','read',array['74000000-0000-4000-8000-000000000002'::uuid])->>'actorId','00000000-0000-4000-8000-00000000000b','activity actor bound to session');
select throws_ok($$insert into message_reactions(message_id,chat_id,user_id,emoji) values('74000000-0000-4000-8000-000000000002','74000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000b','fake')$$,'P0001','stream_activity_server_owned','client cannot create second reaction authority');
select throws_ok($$update message_reads set receipt_visible=false where message_id='74000000-0000-4000-8000-000000000002'$$,'42501','permission denied for table message_reads','client cannot rewrite canonical receipt projection');
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select enqueue_stream_message_event('activity-first',repeat('c',64),jsonb_build_object('type','message.updated','cid','blab:74000000-0000-4000-8000-000000000001','created_at',now(),'message',jsonb_build_object('id','74000000-0000-4000-8000-000000000002')));
select enqueue_stream_message_event('activity-second',repeat('d',64),jsonb_build_object('type','message.updated','cid','blab:74000000-0000-4000-8000-000000000001','created_at',now()+interval '1 second','message',jsonb_build_object('id','74000000-0000-4000-8000-000000000002')));
create temp table claimed_activity as select * from claim_stream_message_events(8);
grant select on claimed_activity to service_role;
select is((select count(*) from claimed_activity where message_id='74000000-0000-4000-8000-000000000002'),1::bigint,'one snapshot job per message per batch');
select is((select count(*) from claim_stream_message_events(8) where message_id='74000000-0000-4000-8000-000000000002'),0::bigint,'second worker cannot race active snapshot');
select ok(finish_stream_message_event('activity-first',(select lease_token from claimed_activity where event_id='activity-first'),true),'first snapshot settles');
select is((select count(*) from claim_stream_message_events(8) where message_id='74000000-0000-4000-8000-000000000002'),1::bigint,'next activity waits until predecessor settles');
reset role;
select * from finish();
rollback;
