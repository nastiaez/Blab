begin;
select plan(10);
insert into chats(id) values('72000000-0000-4000-8000-000000000001');
insert into chat_members(chat_id,user_id,learning_language,mode) values
('72000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000a','de','practice'),
('72000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000b','en','practice');
insert into messages(id,chat_id,sender_id,body,created_at) values('72000000-0000-4000-8000-000000000002','72000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000b','Hello',now()+interval '1 second');
select set_config('request.jwt.claims','{"role":"service_role"}',true);
create temp table readable_fixture as select encode(extensions.digest('Hello','sha256'),'hex') as hash,
 (select language_revision::integer from resolve_message_learning_era('72000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-00000000000a')) as revision,
 '{"mode":"translation","sourceLang":"en","translation":"Hallo","interfaceText":"Hello","explanation":null,"confidence":null,"formAlternatives":null}'::jsonb as result;
grant select on readable_fixture to service_role;
select ok(not has_function_privilege('authenticated','publish_message_readable_variant(uuid,uuid,text,text,integer,text,jsonb,text)','execute'),'only verified server work can publish readable results');
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
select ok(publish_message_readable_variant('72000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-00000000000a','de','en',(select revision from readable_fixture),(select hash from readable_fixture),(select result from readable_fixture),'minimal-source-anchor-v11'),'verified readable text is stored separately');
select ok(not publish_message_readable_variant('72000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-00000000000a','de','en',(select revision from readable_fixture),repeat('0',64),(select result from readable_fixture),'minimal-source-anchor-v11'),'stale source hash is rejected');
select ok(not publish_message_readable_variant('72000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-00000000000a','de','en',(select revision+1 from readable_fixture),(select hash from readable_fixture),(select result from readable_fixture),'minimal-source-anchor-v11'),'wrong era is rejected');
select ok(not publish_message_readable_variant('72000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-00000000000c','de','en',(select revision from readable_fixture),(select hash from readable_fixture),(select result from readable_fixture),'minimal-source-anchor-v11'),'nonmember receives no readable result');
select ok(publish_message_readable_variant('72000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-00000000000a','de','en',(select revision from readable_fixture),(select hash from readable_fixture),(select result||'{"tokens":[]}'::jsonb from readable_fixture),'minimal-source-anchor-v11'),'readable publication accepts normalized metadata without completing word help');
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}',true);
set local role authenticated;
select is((select count(*) from message_readable_variants),1::bigint,'intended viewer can read private ready text');
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000000b","role":"authenticated"}',true);
set local role authenticated;
select is((select count(*) from message_readable_variants),0::bigint,'chat partner cannot read private learning data');
reset role;
select is((select count(*) from message_translations where message_id='72000000-0000-4000-8000-000000000002'),0::bigint,'readable phase never writes incomplete legacy cache');
select set_config('request.jwt.claims','{"role":"service_role"}',true);
set local role service_role;
update messages set body='Changed source' where id='72000000-0000-4000-8000-000000000002';
reset role;
select is((select count(*) from message_readable_variants where message_id='72000000-0000-4000-8000-000000000002'),0::bigint,'edit invalidates readable text before late metadata completion');
select * from finish();
rollback;
