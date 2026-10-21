-- Local isolated DB only; transaction leaves no fixtures or queued requests.
begin;
delete from public.message_preparation_jobs;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email,raw_user_meta_data) values
 ('71111111-1111-4111-8111-711111111111','batch-shared-alice@blab.test','{"name":"Batch Alice"}'),
 ('72222222-2222-4222-8222-722222222222','batch-shared-bob@blab.test','{"name":"Batch Bob"}');
insert into chats(id,member_low_id,member_high_id) values('73333333-3333-4333-8333-733333333333','71111111-1111-4111-8111-711111111111','72222222-2222-4222-8222-722222222222');
insert into chat_members(chat_id,user_id,learning_language) values
 ('73333333-3333-4333-8333-733333333333','71111111-1111-4111-8111-711111111111','de'),
 ('73333333-3333-4333-8333-733333333333','72222222-2222-4222-8222-722222222222','de');
insert into messages(id,chat_id,sender_id,body) values
 ('74444444-4444-4444-8444-744444444444','73333333-3333-4333-8333-733333333333','71111111-1111-4111-8111-711111111111','Hello');
do $$ declare n integer; old_id uuid; old_token uuid; r jsonb; begin
 select count(*) into n from message_preparation_jobs where message_id='74444444-4444-4444-8444-744444444444';
 if n<>2 then raise exception 'expected two viewer jobs, got %',n; end if;
 select count(*) into n from claim_message_preparation_jobs_for_worker(1);
 if n<>2 then raise exception 'limit must not split a viewer batch, got %',n; end if;
 select count(*) into n from claim_message_preparation_jobs_for_worker(10);
 if n<>0 then raise exception 'duplicate concurrent claim'; end if;
 select id,lease_token into old_id,old_token from message_preparation_jobs limit 1;
 update message_preparation_jobs set locked_at=now()-interval '46 seconds';
 select count(*) into n from claim_message_preparation_jobs_for_worker(10);
 if n<>2 then raise exception 'reclaim failed'; end if;
 r:=leased_translation_action(old_id,old_token,'prepare');
 if r->>'status'<>'stale' then raise exception 'stale lease accepted'; end if;
 raise notice 'PASS atomic viewer grouping, duplicate claim exclusion and stale lease fencing';
end $$;
-- Shared target/known language is the production regression: the first cache
-- insert must not prematurely mark the second processing lease ready.
do $$ declare payload jsonb; n integer; begin
 select jsonb_agg(jsonb_build_object('jobId',id,'lease',lease_token,'result',
   jsonb_build_object('mode','translation','sourceLang','en','translation','Hallo',
     'interfaceText','Hello','explanation',null,'confidence',null,
     'tokens',jsonb_build_array(jsonb_build_object('text','Hallo','gloss','Hello','isContent',true,'roman',null)),
     'formAlternatives',null,'contractVersion','minimal-source-anchor-v11')))
 into payload from message_preparation_jobs where message_id='74444444-4444-4444-8444-744444444444';
 if not complete_translation_message_batch(payload) then raise exception 'batch rejected'; end if;
 select count(*) into n from message_preparation_jobs where message_id='74444444-4444-4444-8444-744444444444' and status='ready';
 if n<>2 then raise exception 'both jobs must finish'; end if;
 select count(*) into n from message_readable_variants where message_id='74444444-4444-4444-8444-744444444444';
 if n<>2 then raise exception 'both viewers must receive readable results'; end if;
 if current_setting('blab.atomic_translation_batch',true)='on' then raise exception 'batch flag leaked'; end if;
 raise notice 'PASS same-language batch completion and two readable variants';
end $$;
rollback;
