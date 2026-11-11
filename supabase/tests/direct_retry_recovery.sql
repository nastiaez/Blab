-- BLA-47; run on a disposable canonical database. No retained data changes.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email,raw_user_meta_data) values
 ('91111111-1111-4111-8111-911111111111','retry-alice@blab.test','{"name":"Retry Alice"}'),
 ('92222222-2222-4222-8222-922222222222','retry-bob@blab.test','{"name":"Retry Bob"}');
update profiles set primary_known_language='en',known_languages=array['en'],interface_language='en'
 where id in ('91111111-1111-4111-8111-911111111111','92222222-2222-4222-8222-922222222222');
insert into chats(id,member_low_id,member_high_id) values
 ('93333333-3333-4333-8333-933333333333','91111111-1111-4111-8111-911111111111','92222222-2222-4222-8222-922222222222');
insert into chat_members(chat_id,user_id,learning_language,mode) values
 ('93333333-3333-4333-8333-933333333333','91111111-1111-4111-8111-911111111111','de','practice'),
 ('93333333-3333-4333-8333-933333333333','92222222-2222-4222-8222-922222222222','es','practice');
insert into messages(id,chat_id,sender_id,body) values
 ('94444444-4444-4444-8444-944444444444','93333333-3333-4333-8333-933333333333','91111111-1111-4111-8111-911111111111','Hello
A second paragraph.');
update message_preparation_jobs set status='failed',attempts=4,last_error='provider_timeout'
 where message_id='94444444-4444-4444-8444-944444444444';
select set_config('request.jwt.claims','{"role":"authenticated","sub":"91111111-1111-4111-8111-911111111111"}',true);
do $$ declare r jsonb; n integer; usage_before integer; begin
 r:=request_message_translation_variant('94444444-4444-4444-8444-944444444444','de',false);
 if r->>'status'<>'failed' then raise exception 'reopen restarted exhausted work: %',r; end if;
 r:=request_message_translation_variant('94444444-4444-4444-8444-944444444444','fr',true);
 if r->>'status'<>'forbidden' then raise exception 'unauthorized target admitted'; end if;
 r:=request_message_translation_variant('94444444-4444-4444-8444-944444444444','en',true);
 if r->>'status'<>'pending' then raise exception 'Normal retry not durable: %',r; end if;
 select count(*) into n from message_preparation_jobs where message_id='94444444-4444-4444-8444-944444444444' and viewer_id=auth.uid() and status='queued' and attempts=0;
 if n<>1 then raise exception 'exact viewer job not requeued'; end if;
 if not exists(select 1 from message_preparation_jobs where message_id='94444444-4444-4444-8444-944444444444' and viewer_id<>auth.uid() and status='failed' and attempts=4) then raise exception 'other viewer changed'; end if;
 select day_requests into usage_before from translation_usage where user_id=auth.uid();
 r:=request_message_translation_variant('94444444-4444-4444-8444-944444444444','de',true);
 if r->>'status'<>'pending' then raise exception 'duplicate retry not pending'; end if;
 if (select day_requests from translation_usage where user_id=auth.uid())<>usage_before then raise exception 'duplicate retry charged'; end if;
 if exists(select 1 from message_translation_attempts where message_id='94444444-4444-4444-8444-944444444444') then raise exception 'sync attempt created'; end if;
 if not message_translation_work_pending('94444444-4444-4444-8444-944444444444','de','en') then raise exception 'client pending lookup false'; end if;
 raise notice 'PASS reopen, target authorization, durable retry, viewer isolation, duplicate quota, no sync generation, pending lookup';
end $$;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
-- Simulate a genuine failed worker outcome, then authorize another explicit retry.
update message_preparation_jobs set status='failed',attempts=4 where message_id='94444444-4444-4444-8444-944444444444' and viewer_id='91111111-1111-4111-8111-911111111111';
select set_config('request.jwt.claims','{"role":"authenticated","sub":"91111111-1111-4111-8111-911111111111"}',true);
do $$ begin
 if request_message_translation_variant('94444444-4444-4444-8444-944444444444','de',true)->>'status'<>'pending' then raise exception 'second recovery blocked'; end if;
 raise notice 'PASS terminal failure can recover via explicit retry';
end $$;
-- Canonical leased completion generates both lanes; Normal recovery reads the
-- matching package even though legacy cache is keyed only by learning language.
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select count(*) from claim_message_preparation_jobs_for_worker(10);
do $$ declare payload jsonb; begin
 select jsonb_agg(jsonb_build_object('jobId',id,'lease',lease_token,'result',
  jsonb_build_object('mode','translation','sourceLang','fr','translation','Hallo',
    'interfaceText','Hello','tokens','[]'::jsonb,'formAlternatives',null,
    'contractVersion','minimal-source-anchor-v11')))
 into payload from message_preparation_jobs
 where message_id='94444444-4444-4444-8444-944444444444' and viewer_id='91111111-1111-4111-8111-911111111111';
 if not complete_translation_message_batch(payload) then raise exception 'canonical recovery completion failed'; end if;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"91111111-1111-4111-8111-911111111111"}',true);
do $$ declare r jsonb; n integer; before_count integer; begin
 select day_requests into before_count from translation_usage where user_id=auth.uid();
 select count(*) into n from message_translations where message_id='94444444-4444-4444-8444-944444444444' and target_lang='en';
 if n<>0 then raise exception 'fixture must expose missing legacy known-language row'; end if;
 r:=request_message_translation_variant('94444444-4444-4444-8444-944444444444','en',true);
 if r->>'status'<>'cached' or r->>'targetLang'<>'en' or r->>'translation'<>'Hello' then raise exception 'Normal requested lane not recovered: %',r; end if;
 r:=request_message_translation_variant('94444444-4444-4444-8444-944444444444','de',true);
 if r->>'status'<>'cached' or r->>'translation'<>'Hallo' then raise exception 'Practice lane lost'; end if;
 if (select day_requests from translation_usage where user_id=auth.uid())<>before_count then raise exception 'accepted package recharged'; end if;
 raise notice 'PASS canonical completion resolves distinct Normal and Practice lanes without regeneration';
end $$;
-- Isolated corruption fixture only; no accepted application history is deleted.
delete from message_translations where message_id='94444444-4444-4444-8444-944444444444';
delete from message_readable_variants where message_id='94444444-4444-4444-8444-944444444444';
delete from message_prepared_packages where message_id='94444444-4444-4444-8444-944444444444';
-- Ready without the requested cache is terminal, never phantom pending.
update message_preparation_jobs set status='ready' where message_id='94444444-4444-4444-8444-944444444444' and viewer_id=auth.uid();
do $$ declare before_count integer; r jsonb; begin
 select day_requests into before_count from translation_usage where user_id=auth.uid();
 r:=request_message_translation_variant('94444444-4444-4444-8444-944444444444','de',true);
 if r->>'status'<>'failed' then raise exception 'ready missing-cache job became phantom work'; end if;
 if (select day_requests from translation_usage where user_id=auth.uid())<>before_count then raise exception 'no-op charged quota'; end if;
end $$;
update message_preparation_jobs set status='failed' where message_id='94444444-4444-4444-8444-944444444444' and viewer_id=auth.uid();
update translation_usage set minute_started_at=date_trunc('minute',clock_timestamp()),minute_requests=60 where user_id=auth.uid();
do $$ declare r jsonb; begin
 r:=request_message_translation_variant('94444444-4444-4444-8444-944444444444','de',true);
 if r->>'status'<>'rate_limited' then raise exception 'quota bypass: %',r; end if;
 if exists(select 1 from message_preparation_jobs where message_id='94444444-4444-4444-8444-944444444444' and status<>'failed') then raise exception 'rate-limited work queued'; end if;
 raise notice 'PASS ready-cache-miss terminal state, no-op quota, rate-limit preserved';
end $$;
select set_config('request.jwt.claims','{}',true);
do $$ begin
 if request_message_translation_variant('94444444-4444-4444-8444-944444444444','de',true)->>'status'<>'forbidden' then raise exception 'anonymous admitted'; end if;
 if has_function_privilege('authenticated','public.request_message_translation_variant_direct(uuid,text,boolean)','execute') then raise exception 'private direct helper exposed'; end if;
 raise notice 'PASS anonymous denied and direct helper private';
end $$;
rollback;
