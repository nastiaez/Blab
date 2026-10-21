-- Local-only synthetic results prove authorization/storage/scheduling, not live AI.
begin;
delete from public.message_preparation_jobs;
update public.app_distribution_policy set channel='public',testing_enabled=true;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
select set_config('test.group',(select chat_id::text from public.create_group('100 member AI proof')),true);
select public.set_learning_language(current_setting('test.group')::uuid,'de');
reset role;
create temp table qa_group_viewers as select gen_random_uuid() as id from generate_series(1,99);
insert into auth.users(id,instance_id,aud,role,email,raw_user_meta_data)
 select id,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',
  id::text||'@group-ai.blab.test','{"name":"AI fixture member"}'::jsonb from qa_group_viewers;
insert into public.chat_members(chat_id,user_id,learning_language)
 select current_setting('test.group')::uuid,id,'de' from qa_group_viewers;
set local role authenticated;
insert into public.messages(chat_id,sender_id,body) values(current_setting('test.group')::uuid,auth.uid(),'Hello everyone')
 returning set_config('test.message',id::text,true);
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
create temp table claimed as select * from public.claim_message_preparation_jobs_for_worker(1);
do $$declare n integer; j record; r jsonb; prepared jsonb; payload jsonb; outcomes jsonb; begin
 if (select count(*) from claimed)<>100 then raise exception '100-viewer group stalled or split'; end if;
 if exists(select 1 from public.claim_message_preparation_jobs_for_worker(10)) then raise exception 'message claimed twice'; end if;
 prepared:=public.prepare_translation_viewers((select jsonb_agg(jsonb_build_object('id',id,'lease',lease_token)) from claimed));
 if jsonb_array_length(prepared)<>100 then raise exception 'bulk preparation missing viewers'; end if;
 for j in select * from claimed loop
  select value->'prepared' into r from jsonb_array_elements(prepared) where value->>'id'=j.id::text;
  if r->>'status'<>'ready' or r#>>'{formContext,group}'<>'true' then raise exception 'group preparation missing'; end if;
  if r#>>'{formContext,authorName}'<>'Alice Local' then raise exception 'arbitrary member used as author'; end if;
 end loop;
 if not public.renew_message_preparation_leases((select jsonb_agg(jsonb_build_object('id',id,'lease',lease_token)) from claimed)) then raise exception 'lease renewal failed'; end if;
 select jsonb_agg(jsonb_build_object('jobId',id,'lease',lease_token,'result',jsonb_build_object(
  'mode','translation','sourceLang','en','translation','Hallo zusammen','interfaceText','Hello everyone',
  'tokens','[]'::jsonb,'formAlternatives',null,'explanation',null,'confidence',null,'contractVersion','minimal-source-anchor-v11'
 ))) into payload from claimed;
 outcomes:=public.complete_group_translation_viewers(jsonb_set(payload,'{0,lease}',to_jsonb(gen_random_uuid())));
 if (select count(*) from jsonb_array_elements(outcomes) where value->>'error' is null)<>99 then raise exception 'one stale viewer blocked others'; end if;
 outcomes:=public.complete_group_translation_viewers(jsonb_build_array(payload->0));
 if outcomes#>>'{0,error}' is not null then raise exception 'valid viewer recovery failed'; end if;
 if (select count(*) from public.message_prepared_packages where message_id=current_setting('test.message')::uuid)<>100 then raise exception 'private group packages missing'; end if;
 if exists(select 1 from public.message_translations where message_id=current_setting('test.message')::uuid) then raise exception 'unscoped group legacy cache written'; end if;
 if (select count(*) from public.message_readable_variants where message_id=current_setting('test.message')::uuid)<>100 then raise exception 'readable group variants missing'; end if;
end $$;
-- Authenticated clients cannot read or populate the shared artifact store.
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
do $$begin
 if (select count(*) from public.message_prepared_packages where chat_id=current_setting('test.group')::uuid)<>1 then raise exception 'other viewers packages leaked'; end if;
 begin perform public.group_translation_artifact(current_setting('test.message')::uuid,repeat('a',64),repeat('b',64),null);
  raise exception 'client accessed shared artifact cache'; exception when insufficient_privilege then null; end;
end $$;
rollback;
