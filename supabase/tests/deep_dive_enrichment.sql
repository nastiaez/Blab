-- Dedicated disposable local database ONLY. No hosted/shared fixture execution.
begin;
do $$begin if current_setting('blab.allow_deep_dive_fixture',true) is distinct from 'isolated-local-only' then raise exception 'isolated_local_backend_required';end if;end$$;
-- Fixture-only transactional suppression of external dispatch. Rolled back with fixtures.
alter table public.message_preparation_jobs disable trigger dispatch_message_preparation_jobs;
alter table public.push_notification_events disable trigger send_push_notification_event;
alter table public.stream_event_inbox disable trigger dispatch_stream_reconciliation;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into public.app_distribution_policy(singleton,channel) values(true,'public') on conflict(singleton) do update set channel='public';
insert into auth.users(id,email,raw_user_meta_data) values
('dd111111-1111-4111-8111-111111111111','dd-a@blab.test','{"name":"Synthetic A"}'),
('dd222222-2222-4222-8222-222222222222','dd-b@blab.test','{"name":"Synthetic B"}'),
('dd333333-3333-4333-8333-333333333333','dd-c@blab.test','{"name":"Synthetic outsider"}');
update public.profiles set primary_known_language='en' where id in ('dd111111-1111-4111-8111-111111111111','dd222222-2222-4222-8222-222222222222');
insert into public.chats(id,member_low_id,member_high_id) values('dd444444-4444-4444-8444-444444444444','dd111111-1111-4111-8111-111111111111','dd222222-2222-4222-8222-222222222222');
insert into public.chat_members(chat_id,user_id,learning_language,mode) values
('dd444444-4444-4444-8444-444444444444','dd111111-1111-4111-8111-111111111111','es','practice'),
('dd444444-4444-4444-8444-444444444444','dd222222-2222-4222-8222-222222222222','es','practice');
insert into public.messages(id,chat_id,sender_id,body) values('dd555555-5555-4555-8555-555555555555','dd444444-4444-4444-8444-444444444444','dd222222-2222-4222-8222-222222222222','Hola mundo');
create temp table dd_test_state(lease uuid,source text);
insert into dd_test_state(source) select encode(digest(convert_to('Hola mundo','UTF8'),'sha256'),'hex');
do $$begin
 if has_table_privilege('authenticated','public.message_learning_enrichments','SELECT') or has_table_privilege('anon','public.message_learning_enrichments','SELECT') or has_table_privilege('service_role','public.message_learning_enrichments','INSERT') then raise exception 'cache direct ACL exposed';end if;
 if has_function_privilege('authenticated','public.claim_deep_dive_enrichment(uuid,uuid,text,text,text,text,bigint,text,boolean)','EXECUTE') or has_function_privilege('anon','public.finish_deep_dive_enrichment(uuid,text,uuid,jsonb)','EXECUTE') then raise exception 'cache RPC exposed';end if;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"dd111111-1111-4111-8111-111111111111"}',true);
do $$begin
 begin perform public.claim_deep_dive_enrichment('dd111111-1111-4111-8111-111111111111','dd555555-5555-4555-8555-555555555555',repeat('a',64),(select source from dd_test_state),'en','es',1,'vocabulary');raise exception 'missing service check';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
do $$declare a jsonb;b jsonb;begin
 a:=public.claim_deep_dive_enrichment('dd333333-3333-4333-8333-333333333333','dd555555-5555-4555-8555-555555555555',repeat('a',64),(select source from dd_test_state),'en','es',1,'vocabulary');if a->>'status'<>'forbidden' then raise exception 'outsider admitted';end if;
 a:=public.claim_deep_dive_enrichment('dd111111-1111-4111-8111-111111111111','dd555555-5555-4555-8555-555555555555',repeat('a',64),(select source from dd_test_state),'en','es',1,'vocabulary');if a->>'status'<>'claimed' then raise exception 'first claim %',a;end if;update dd_test_state set lease=(a->>'lease')::uuid;
 b:=public.claim_deep_dive_enrichment('dd111111-1111-4111-8111-111111111111','dd555555-5555-4555-8555-555555555555',repeat('a',64),(select source from dd_test_state),'en','es',1,'vocabulary');if b->>'status'<>'pending' then raise exception 'duplicate did not coalesce';end if;
 if (select day_requests from public.translation_usage where user_id='dd111111-1111-4111-8111-111111111111')<>1 then raise exception 'duplicate charged';end if;
 if public.finish_deep_dive_enrichment('dd111111-1111-4111-8111-111111111111',repeat('a',64),gen_random_uuid(),'{"meaning":"wrong lease"}') then raise exception 'stale lease accepted';end if;
 if not public.finish_deep_dive_enrichment('dd111111-1111-4111-8111-111111111111',repeat('a',64),(select lease from dd_test_state),'{"meaning":"hello"}') then raise exception 'completion failed';end if;
 b:=public.claim_deep_dive_enrichment('dd111111-1111-4111-8111-111111111111','dd555555-5555-4555-8555-555555555555',repeat('a',64),(select source from dd_test_state),'en','es',1,'vocabulary');if b->>'status'<>'cached' or b->'analysis'->>'meaning'<>'hello' then raise exception 'durable cache miss';end if;
 if (select day_requests from public.translation_usage where user_id='dd111111-1111-4111-8111-111111111111')<>1 then raise exception 'cache hit charged';end if;
 b:=public.claim_deep_dive_enrichment('dd222222-2222-4222-8222-222222222222','dd555555-5555-4555-8555-555555555555',repeat('a',64),(select source from dd_test_state),'en','es',1,'vocabulary');if b->>'status'='cached' then raise exception 'cross-viewer cache disclosure';end if;
end$$;
-- Shared translator counters are reused, never reset/refunded or extended.
update public.translation_usage set minute_requests=59,day_requests=199,day_characters=99990 where user_id='dd111111-1111-4111-8111-111111111111';
do $$declare a jsonb;begin
 a:=public.claim_deep_dive_enrichment('dd111111-1111-4111-8111-111111111111','dd555555-5555-4555-8555-555555555555',repeat('b',64),(select source from dd_test_state),'en','es',1,'vocabulary');if a->>'status'<>'claimed' then raise exception 'last shared allowance rejected';end if;
 a:=public.claim_deep_dive_enrichment('dd111111-1111-4111-8111-111111111111','dd555555-5555-4555-8555-555555555555',repeat('c',64),(select source from dd_test_state),'en','es',1,'vocabulary');if a->>'status'<>'rate_limited' then raise exception 'shared quota expanded %',a;end if;
 if (select day_requests from public.translation_usage where user_id='dd111111-1111-4111-8111-111111111111')<>200 then raise exception 'quota reset/refunded';end if;
end$$;
update public.profiles set primary_known_language='uk' where id='dd222222-2222-4222-8222-222222222222';
do $$begin if public.finish_deep_dive_enrichment('dd222222-2222-4222-8222-222222222222',repeat('a',64),(select lease_token from public.message_learning_enrichments where viewer_id='dd222222-2222-4222-8222-222222222222'),'{"meaning":"stale preference"}') then raise exception 'stale preferences published';end if;end$$;
-- Crash/orphan leases must become failed and participate in the same bounded cache pruning.
insert into public.message_learning_enrichments(viewer_id,context_key,message_id,source_hash,known_lang,target_lang,language_revision,kind,status,lease_token,locked_until,expires_at,updated_at)
select 'dd111111-1111-4111-8111-111111111111',md5(i::text)||md5('orphan'||i::text),'dd555555-5555-4555-8555-555555555555',(select source from dd_test_state),'en','es',1,'vocabulary','processing',gen_random_uuid(),clock_timestamp()-interval '1 minute',clock_timestamp()+interval '24 hours',clock_timestamp()-interval '61 seconds' from generate_series(1,130) i;
-- Only this rolled-back synthetic user's counters are initialized for an independent test boundary.
update public.translation_usage set minute_requests=0,day_requests=0,day_characters=0 where user_id='dd111111-1111-4111-8111-111111111111';
do $$declare a jsonb;begin
 a:=public.claim_deep_dive_enrichment('dd111111-1111-4111-8111-111111111111','dd555555-5555-4555-8555-555555555555',repeat('e',64),(select source from dd_test_state),'en','es',1,'vocabulary');
 if a->>'status'<>'claimed' or (select count(*) from public.message_learning_enrichments where viewer_id='dd111111-1111-4111-8111-111111111111')>128 or exists(select 1 from public.message_learning_enrichments where viewer_id='dd111111-1111-4111-8111-111111111111' and status='processing' and locked_until<clock_timestamp()) then raise exception 'orphan cache bound violated';end if;
end$$;
update public.chat_members set history_cleared_at=clock_timestamp() where user_id='dd111111-1111-4111-8111-111111111111';
do $$declare a jsonb;begin a:=public.claim_deep_dive_enrichment('dd111111-1111-4111-8111-111111111111','dd555555-5555-4555-8555-555555555555',repeat('a',64),(select source from dd_test_state),'en','es',1,'vocabulary');if a->>'status'<>'forbidden' then raise exception 'cleared history cache accessible';end if;end$$;
update public.messages set body='Changed source' where id='dd555555-5555-4555-8555-555555555555';
do $$begin if exists(select 1 from public.message_learning_enrichments where message_id='dd555555-5555-4555-8555-555555555555') then raise exception 'source edit did not invalidate new cache';end if;raise notice 'PASS service ACL, outsider isolation, duplicate quota, lease fence, durable cache, shared ceilings, stale preferences, cleared history, source invalidation';end$$;
rollback;
