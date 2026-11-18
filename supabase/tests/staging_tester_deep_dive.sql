-- OFFLINE MOCK ONLY; not provider evidence.
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
('e2111111-1111-4111-8111-111111111111','e2-a@blab.test','{"name":"Synthetic A"}'),
('e2222222-2222-4222-8222-222222222222','e2-b@blab.test','{"name":"Synthetic B"}'),
('e2333333-3333-4333-8333-333333333333','e2-c@blab.test','{"name":"Synthetic outsider"}');
update public.profiles set primary_known_language='en' where id in ('e2111111-1111-4111-8111-111111111111','e2222222-2222-4222-8222-222222222222');
insert into public.chats(id,member_low_id,member_high_id) values('e2444444-4444-4444-8444-444444444444','e2111111-1111-4111-8111-111111111111','e2222222-2222-4222-8222-222222222222');
insert into public.chat_members(chat_id,user_id,learning_language,mode) values
('e2444444-4444-4444-8444-444444444444','e2111111-1111-4111-8111-111111111111','es','practice'),
('e2444444-4444-4444-8444-444444444444','e2222222-2222-4222-8222-222222222222','es','practice');
insert into public.messages(id,chat_id,sender_id,body) values('e2555555-5555-4555-8555-555555555555','e2444444-4444-4444-8444-444444444444','e2222222-2222-4222-8222-222222222222','Hola mundo');
create temp table e2_test_state(lease uuid,source text);
insert into e2_test_state(source) select encode(digest(convert_to('Hola mundo','UTF8'),'sha256'),'hex');
create function pg_temp.claim142(k text default repeat('a',64), rel text default repeat('a',40)) returns jsonb language sql as $$
 select public.claim_hosted_deep_dive_enrichment('e2111111-1111-4111-8111-111111111111','e2555555-5555-4555-8555-555555555555',k,(select source from e2_test_state),'en','es',1,'vocabulary',rel,false)
$$;
create function pg_temp.dispatch142(l uuid,rel text default repeat('a',40)) returns boolean language sql as $$
 select public.staging_deep_dive_dispatch('e2111111-1111-4111-8111-111111111111','e2555555-5555-4555-8555-555555555555',repeat('a',64),(select source from e2_test_state),'en','es',1,'vocabulary',rel,l)
$$;
do $$declare role_name text;begin
 foreach role_name in array array['anon','authenticated','service_role'] loop
 if has_schema_privilege(role_name,'blab_staging','USAGE') or has_table_privilege(role_name,'blab_staging.rollouts','SELECT,INSERT,UPDATE,DELETE') or has_table_privilege(role_name,'blab_staging.dispatches','SELECT,INSERT,UPDATE,DELETE') or has_function_privilege(role_name,'blab_staging.activate(text,text)','EXECUTE') or has_function_privilege(role_name,'blab_staging.deactivate(uuid,text)','EXECUTE') then raise exception 'private ACL leak %',role_name;end if;
 end loop;
 if exists(select 1 from blab_staging.rollouts) then raise exception 'activation seed';end if;
 if pg_temp.claim142()->>'status'<>'forbidden' then raise exception 'default open';end if;
end$$;
select blab_staging.activate(repeat('a',40),'OFFLINE MOCK approval evidence only');
do $$begin if pg_temp.claim142()->>'status'<>'forbidden' then raise exception 'public policy admitted';end if;end$$;
update public.app_distribution_policy set channel='test',testing_enabled=true,testing_expires_at=null;
insert into public.test_app_members(user_id) values('e2111111-1111-4111-8111-111111111111'),('e2222222-2222-4222-8222-222222222222');
do $$declare v jsonb;l uuid;begin
 if pg_temp.claim142(repeat('a',64),repeat('b',40))->>'status'<>'forbidden' then raise exception 'revision ignored';end if;
 v:=pg_temp.claim142();
 if v->>'status'<>'claimed' or v->>'admissionClass'<>'tester' or v ? 'qaNonce' then raise exception 'tester admission %',v;end if;
 l:=(v->>'lease')::uuid;update e2_test_state set lease=l;
 if pg_temp.claim142()->>'status'<>'pending' then raise exception 'duplicate not pending';end if;
 if pg_temp.dispatch142(gen_random_uuid()) then raise exception 'stale lease';end if;
 if pg_temp.dispatch142(l,repeat('b',40)) then raise exception 'wrong revision dispatch';end if;
 update public.test_app_members set enabled=false where user_id='e2111111-1111-4111-8111-111111111111';
 if pg_temp.dispatch142(l) then raise exception 'revoked tester dispatch';end if;
 update public.test_app_members set enabled=true where user_id='e2111111-1111-4111-8111-111111111111';
 update public.message_learning_enrichments set locked_until=clock_timestamp()-interval '1 second' where viewer_id='e2111111-1111-4111-8111-111111111111';
 if pg_temp.dispatch142(l) then raise exception 'expired lease dispatch';end if;
 update public.message_learning_enrichments set locked_until=clock_timestamp()+interval '60 seconds' where viewer_id='e2111111-1111-4111-8111-111111111111';
 if public.staging_deep_dive_dispatch('e2111111-1111-4111-8111-111111111111','e2555555-5555-4555-8555-555555555555',repeat('b',64),(select source from e2_test_state),'en','es',1,'vocabulary',repeat('a',40),l) then raise exception 'cross context dispatch';end if;
 if not pg_temp.dispatch142(l) or pg_temp.dispatch142(l) then raise exception 'CAS must dispatch exactly once';end if;
 if (select day_requests from public.translation_usage where user_id='e2111111-1111-4111-8111-111111111111')<>1 then raise exception 'pending charged';end if;
end$$;
-- Normal publication/cache do not charge again; ordinary failed admission retains cooldown.
do $$declare v jsonb;begin
 if not public.finish_deep_dive_enrichment('e2111111-1111-4111-8111-111111111111',repeat('a',64),(select lease from e2_test_state),'{"meaning":"OFFLINE MOCK cached"}') then raise exception 'completion failed';end if;
 if pg_temp.claim142()->>'status'<>'cached' then raise exception 'cache miss';end if;
 if (select day_requests from public.translation_usage where user_id='e2111111-1111-4111-8111-111111111111')<>1 then raise exception 'cache charged';end if;
 v:=pg_temp.claim142(repeat('b',64));
 if v->>'status'<>'claimed' then raise exception 'second context denied %',v;end if;
 perform public.finish_deep_dive_enrichment('e2111111-1111-4111-8111-111111111111',repeat('b',64),(v->>'lease')::uuid,null);
 if pg_temp.claim142(repeat('b',64))->>'status'<>'failed' then raise exception 'implicit retry granted';end if;
 if (select day_requests from public.translation_usage where user_id='e2111111-1111-4111-8111-111111111111')<>2 then raise exception 'failure refunded';end if;
end$$;
-- Closed QA actors always take strict141 path, even during an active operational rollout.
insert into blab_qa.actors values('e2111111-1111-4111-8111-111111111111');
do $$begin
 if pg_temp.claim142()->>'status'<>'forbidden' or pg_temp.dispatch142((select lease from e2_test_state)) then raise exception 'QA tombstone bypass';end if;
end$$;
-- Sender tombstone scopes the whole message/chat path independently of viewer.
insert into blab_qa.actors values('e2222222-2222-4222-8222-222222222222');
delete from blab_qa.actors where actor='e2111111-1111-4111-8111-111111111111';
do $$begin if pg_temp.claim142()->>'status'<>'forbidden' then raise exception 'QA scope bypass';end if;end$$;
select blab_staging.deactivate(id,'OFFLINE MOCK deactivation audit evidence') from blab_staging.rollouts where deactivated_at is null;
do $$begin if pg_temp.dispatch142((select lease from e2_test_state)) then raise exception 'deactivated dispatch';end if;end$$;
rollback;
