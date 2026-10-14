begin;
select plan(12);
select ok(not has_table_privilege('authenticated','stream_media_orphans','select'),'orphan URLs remain private');
select ok(not has_function_privilege('authenticated','queue_stream_media_orphans(uuid,uuid,uuid,uuid,jsonb)','execute'),'client cannot request arbitrary file deletion');
insert into auth.users(id,email) values
 ('97000000-0000-4000-8000-00000000000a','orphan-actor@blab.test'),
 ('97000000-0000-4000-8000-00000000000b','orphan-partner@blab.test');
insert into chats(id) values('97000000-0000-4000-8000-000000000001');
insert into chat_members(chat_id,user_id,learning_language) values
 ('97000000-0000-4000-8000-000000000001','97000000-0000-4000-8000-00000000000a','uk'),
 ('97000000-0000-4000-8000-000000000001','97000000-0000-4000-8000-00000000000b','de');
insert into chat_message_transports(chat_id,provider,migration_state) values('97000000-0000-4000-8000-000000000001','stream','active');
insert into stream_media_uploads(message_id,chat_id,actor_id,source_hash,preview_hash,status,lease_token,locked_at) values
 ('97000000-0000-4000-8000-000000000002','97000000-0000-4000-8000-000000000001','97000000-0000-4000-8000-00000000000a',repeat('a',64),repeat('b',64),'processing','97000000-0000-4000-8000-000000000003',now());
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select is(queue_stream_media_orphans('97000000-0000-4000-8000-00000000000a','97000000-0000-4000-8000-000000000001','97000000-0000-4000-8000-000000000002','97000000-0000-4000-8000-000000000003','[{"kind":"file","url":"https://files.stream-io-cdn.com/orphan.png"}]'),1,'uncommitted upload enters durable cleanup');
select is((select status from stream_media_uploads where message_id='97000000-0000-4000-8000-000000000002'),'pending','failed upload lease is canceled before deletion');
select ok(not finish_stream_media_upload('97000000-0000-4000-8000-000000000002','97000000-0000-4000-8000-000000000003',null),'late completion cannot publish a canceled upload');
select is(queue_stream_media_orphans('97000000-0000-4000-8000-00000000000a','97000000-0000-4000-8000-000000000001','97000000-0000-4000-8000-000000000002','97000000-0000-4000-8000-000000000003','[{"kind":"file","url":"https://files.stream-io-cdn.com/orphan.png"}]'),0,'duplicate cleanup is idempotent');
reset role;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"97000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
select throws_ok($$select reserve_stream_media_upload('97000000-0000-4000-8000-000000000001','97000000-0000-4000-8000-000000000002',repeat('a',64),repeat('b',64))$$,'P0001','upload_cleanup_pending','retry cannot race cleanup of its old asset');
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
create temp table orphan_claim as select * from claim_stream_media_orphans(4);
select is((select count(*)::integer from orphan_claim),1,'one asset is leased');
select ok(not finish_stream_media_orphan((select asset_hash from orphan_claim),gen_random_uuid(),true),'stale cleanup lease cannot settle');
select ok(finish_stream_media_orphan((select asset_hash from orphan_claim),(select lease_token from orphan_claim),true),'exact lease confirms provider removal');
select is((select status from stream_media_orphans limit 1),'done','completed cleanup stops retrying');
insert into stream_media_uploads(message_id,chat_id,actor_id,source_hash,preview_hash,status,attachment) values
 ('97000000-0000-4000-8000-000000000004','97000000-0000-4000-8000-000000000001','97000000-0000-4000-8000-00000000000a',repeat('c',64),repeat('d',64),'ready','{"asset_url":"https://files.stream-io-cdn.com/committed.png","thumb_url":"https://files.stream-io-cdn.com/committed.png"}');
select is(queue_stream_media_orphans('97000000-0000-4000-8000-00000000000a','97000000-0000-4000-8000-000000000001','97000000-0000-4000-8000-000000000004','97000000-0000-4000-8000-000000000003','[{"kind":"file","url":"https://files.stream-io-cdn.com/committed.png"}]'),0,'ambiguous HTTP failure never queues a committed photo');
reset role;
select * from finish();
rollback;
