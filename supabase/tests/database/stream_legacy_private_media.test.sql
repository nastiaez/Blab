begin;
select plan(5);
select ok(not has_function_privilege('authenticated','queue_account_private_media_cleanup(uuid)','execute'),'client cannot queue another account physical deletion');
insert into chats(id) values('a1000000-0000-4000-8000-000000000001');
insert into storage.objects(bucket_id,name,owner) values
('message-media','a1000000-0000-4000-8000-000000000001/00000000-0000-4000-8000-00000000000a/old-original.png','00000000-0000-4000-8000-00000000000a'),
('message-media','a1000000-0000-4000-8000-000000000001/00000000-0000-4000-8000-00000000000b/partner-original.png','00000000-0000-4000-8000-00000000000b');
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select is((select count(*) from queue_account_private_media_cleanup('00000000-0000-4000-8000-00000000000a')),1::bigint,'old client-owned original is captured before auth cascade');
select is((select count(*) from stream_private_media_assets where bucket_id='message-media' and actor_id='00000000-0000-4000-8000-00000000000b'),0::bigint,'partner stored photo is not queued');
select is((select count(*) from queue_account_private_media_cleanup('00000000-0000-4000-8000-00000000000a')),1::bigint,'interrupted deletion remains idempotent');
select is((select count(*) from stream_private_media_assets where bucket_id='message-media'),1::bigint,'retries cannot duplicate legacy cleanup ownership');
reset role;
select * from finish();
rollback;
