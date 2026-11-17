-- BLA-22: isolated local backend only. Transaction rolls back every fixture.
-- Invoke with PGOPTIONS='-c blab.allow_translation_report_fixture=local-only'.
begin;
do $$ begin
 if current_setting('blab.allow_translation_report_fixture',true) is distinct from 'local-only' then
  raise exception 'isolated_local_backend_required';
 end if;
end $$;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into public.translation_report_environment(singleton,environment) values(true,'local')
 on conflict(singleton) do update set environment='local';
update app_distribution_policy set channel='public' where singleton;
insert into auth.users(id,email,raw_user_meta_data) values
 ('22111111-1111-4111-8111-111111111111','report-a@blab.test','{"name":"Report A"}'),
 ('22222222-2222-4222-8222-222222222222','report-b@blab.test','{"name":"Report B"}'),
 ('22333333-3333-4333-8333-333333333333','report-c@blab.test','{"name":"Report C"}');
insert into chats(id,member_low_id,member_high_id) values
 ('22444444-4444-4444-8444-444444444444','22111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222');
insert into chat_members(chat_id,user_id,learning_language,mode) values
 ('22444444-4444-4444-8444-444444444444','22111111-1111-4111-8111-111111111111','de','practice'),
 ('22444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222','es','normal');
insert into messages(id,chat_id,sender_id,body) values
 ('22555555-5555-4555-8555-555555555555','22444444-4444-4444-8444-444444444444','22222222-2222-4222-8222-222222222222','Ist es distracting for you?');
create temp table report_before as select
 (select md5(coalesce(jsonb_agg(to_jsonb(m) order by m.id)::text,'')) from messages m) as messages,
 (select md5(coalesce(jsonb_agg(to_jsonb(t) order by t.message_id,t.target_lang)::text,'')) from message_translations t) as translations,
 (select md5(coalesce(jsonb_agg(to_jsonb(j) order by j.id)::text,'')) from message_preparation_jobs j) as jobs,
 (select count(*) from reports) as moderation;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"22111111-1111-4111-8111-111111111111"}',true);
do $$ declare a uuid;b uuid; begin
 a:=submit_translation_report('22666666-6666-4666-8666-666666666666','22555555-5555-4555-8555-555555555555','partial','Keep note','Displayed text','de','{"environment":"production","platform":"android","app_version":"1+1","secret":"ignored"}');
 b:=submit_translation_report('22666666-6666-4666-8666-666666666666','22555555-5555-4555-8555-555555555555','partial','Keep note','Displayed text','de','{}');
 if a<>b then raise exception 'duplicate submission created twice';end if;
 if not exists(select 1 from translation_reports where id=a and environment='local' and note='Keep note'
   and original_text='Ist es distracting for you?' and not client_metadata ? 'secret') then raise exception 'snapshot/metadata invalid';end if;
 begin
  perform submit_translation_report(gen_random_uuid(),'22555555-5555-4555-8555-555555555555','spam','','','de','{}');
  raise exception 'moderation reason accepted';
 exception when invalid_parameter_value then null;end;
 begin
  perform submit_translation_report(gen_random_uuid(),'22555555-5555-4555-8555-555555555555','other',repeat('x',1001),'','de','{}');
  raise exception 'oversize note accepted';
 exception when invalid_parameter_value then null;end;
 begin
  perform triage_translation_report(a,'resolved','not allowed');
  raise exception 'user triaged report';
 exception when insufficient_privilege then null;end;
 for i in 1..4 loop
  perform submit_translation_report(gen_random_uuid(),'22555555-5555-4555-8555-555555555555','failing','','','de','{}');
 end loop;
 begin
  perform submit_translation_report(gen_random_uuid(),'22555555-5555-4555-8555-555555555555','failing','','','de','{}');
  raise exception 'rate limit bypass';
 exception when raise_exception then
  if sqlerrm<>'report_rate_limited' then raise;end if;
 end;
 b:=submit_translation_report('22666666-6666-4666-8666-666666666666','22555555-5555-4555-8555-555555555555','partial','Keep note','Displayed text','de','{}');
 if a<>b then raise exception 'rate limit broke idempotent retry';end if;
end $$;
-- SECURITY DEFINER intake must reproduce restrictive message visibility policies.
update chat_members set history_cleared_at=now() where user_id='22222222-2222-4222-8222-222222222222';
select set_config('request.jwt.claims','{"role":"authenticated","sub":"22222222-2222-4222-8222-222222222222"}',true);
do $$ begin
 begin
  perform submit_translation_report(gen_random_uuid(),'22555555-5555-4555-8555-555555555555','other','','','es','{}');
  raise exception 'cleared history disclosed through report snapshot';
 exception when insufficient_privilege then null;end;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"22333333-3333-4333-8333-333333333333"}',true);
do $$ begin
 begin
  perform submit_translation_report(gen_random_uuid(),'22555555-5555-4555-8555-555555555555','other','','','de','{}');
  raise exception 'nonmember accessed message';
 exception when insufficient_privilege then null;end;
 if has_table_privilege('authenticated','public.translation_reports','SELECT')
  or has_table_privilege('authenticated','public.translation_reports','INSERT')
  or has_table_privilege('authenticated','public.translation_reports','UPDATE')
  or has_table_privilege('anon','public.translation_reports','SELECT') then raise exception 'private inbox exposed';end if;
end $$;
set local role authenticated;
do $$ begin
 begin
  perform 1 from public.translation_reports;
  raise exception 'authenticated inbox read allowed';
 exception when insufficient_privilege then null;end;
 begin
  perform public.triage_translation_report(gen_random_uuid(),'resolved','forbidden');
  raise exception 'authenticated triage allowed';
 exception when insufficient_privilege then null;end;
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select triage_translation_report(id,'investigating','Local test only') from translation_reports where submission_id='22666666-6666-4666-8666-666666666666';
do $$ begin
 if not exists(select 1 from report_before b where
  b.messages=(select md5(coalesce(jsonb_agg(to_jsonb(m) order by m.id)::text,'')) from messages m)
  and b.translations=(select md5(coalesce(jsonb_agg(to_jsonb(t) order by t.message_id,t.target_lang)::text,'')) from message_translations t)
  and b.jobs=(select md5(coalesce(jsonb_agg(to_jsonb(j) order by j.id)::text,'')) from message_preparation_jobs j)
  and b.moderation=(select count(*) from reports)) then raise exception 'reporting mutated messages, translation work or moderation';end if;
 raise notice 'PASS idempotency, rate bound, message membership, bounded snapshots, trusted environment, private triage, no translation/moderation writes';
end $$;
rollback;
