begin;
select plan(14);
select ok(not has_table_privilege('authenticated','stream_history_cutovers','select'),'migration proofs and source fingerprints remain private');
select ok(not has_function_privilege('authenticated','freeze_stream_history(uuid)','execute'),'clients cannot freeze chats');
select ok(not has_function_privilege('authenticated','finish_stream_history_cutover(uuid,uuid,text,text,text)','execute'),'clients cannot switch canonical authority');
insert into chats(id) values('99000000-0000-4000-8000-000000000001'),('99000000-0000-4000-8000-000000000004');
insert into chat_members(chat_id,user_id,learning_language) values
('99000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000a','de'),
('99000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000b','en'),
('99000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-00000000000a','de');
insert into messages(id,chat_id,sender_id,body) values('99000000-0000-4000-8000-000000000002','99000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000a','Historical original');
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select throws_ok($$select freeze_stream_history('99000000-0000-4000-8000-000000000004')$$,'P0001','history_pair_not_ready','unclaimed invitation cannot half-migrate');
create temp table cutover_fixture as select freeze_stream_history('99000000-0000-4000-8000-000000000001') as lease;
grant select on cutover_fixture to authenticated;
select is((select provider from chat_message_transports where chat_id='99000000-0000-4000-8000-000000000001'),'supabase','freeze alone does not activate Stream');
select throws_ok($$select finish_stream_history_cutover('99000000-0000-4000-8000-000000000001',gen_random_uuid(),(select lease->>'sourceHash' from cutover_fixture),repeat('a',64),'activate')$$,'P0001','cutover_lease_mismatch','stale operator cannot promote a newer migration');
select throws_ok($$select finish_stream_history_cutover('99000000-0000-4000-8000-000000000001',(select (lease->>'leaseToken')::uuid from cutover_fixture),(select lease->>'sourceHash' from cutover_fixture),null,'activate')$$,'P0001','history_readback_proof_required','source export alone is not vendor acceptance');
reset role;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
select throws_ok($$update messages set body='Racing edit' where id='99000000-0000-4000-8000-000000000002'$$,'P0001','chat_migration_in_progress','legacy writer cannot change the exported history');
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
update messages set body='Operator drift' where id='99000000-0000-4000-8000-000000000002';
select throws_ok($$select finish_stream_history_cutover('99000000-0000-4000-8000-000000000001',(select (lease->>'leaseToken')::uuid from cutover_fixture),(select lease->>'sourceHash' from cutover_fixture),repeat('a',64),'activate')$$,'P0001','history_source_changed','even privileged drift invalidates readback');
select ok(finish_stream_history_cutover('99000000-0000-4000-8000-000000000001',(select (lease->>'leaseToken')::uuid from cutover_fixture),null,null,'abort'),'abort unlocks legacy history without overwriting operator changes');
update cutover_fixture set lease=freeze_stream_history('99000000-0000-4000-8000-000000000001');
select ok(finish_stream_history_cutover('99000000-0000-4000-8000-000000000001',(select (lease->>'leaseToken')::uuid from cutover_fixture),(select lease->>'sourceHash' from cutover_fixture),repeat('a',64),'activate'),'unchanged source and retained readback permit explicit activation');
select ok(finish_stream_history_cutover('99000000-0000-4000-8000-000000000001',(select (lease->>'leaseToken')::uuid from cutover_fixture),(select lease->>'sourceHash' from cutover_fixture),repeat('b',64),'rollback'),'verified pre-traffic rollback preserves the original history');
update cutover_fixture set lease=freeze_stream_history('99000000-0000-4000-8000-000000000001');
select ok(finish_stream_history_cutover('99000000-0000-4000-8000-000000000001',(select (lease->>'leaseToken')::uuid from cutover_fixture),(select lease->>'sourceHash' from cutover_fixture),repeat('a',64),'activate'),'a rolled-back chat can be freshly reviewed');
update messages set body='New canonical activity' where id='99000000-0000-4000-8000-000000000002';
select throws_ok($$select finish_stream_history_cutover('99000000-0000-4000-8000-000000000001',(select (lease->>'leaseToken')::uuid from cutover_fixture),(select lease->>'sourceHash' from cutover_fixture),repeat('b',64),'rollback')$$,'P0001','history_source_changed','rollback cannot silently discard post-cutover activity');
reset role;
select * from finish();
rollback;
