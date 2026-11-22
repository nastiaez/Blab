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
create function pg_temp.claim_production(k text default repeat('a',64), rel text default repeat('a',40), viewer uuid default 'e2111111-1111-4111-8111-111111111111') returns jsonb language sql as $$
 select public.claim_production_deep_dive_enrichment(viewer,'e2555555-5555-4555-8555-555555555555',k,(select source from e2_test_state),'en','es',1,'vocabulary',rel,false)
$$;
create function pg_temp.dispatch_production(l uuid,rel text default repeat('a',40)) returns boolean language sql as $$
 select public.production_deep_dive_dispatch('e2111111-1111-4111-8111-111111111111','e2555555-5555-4555-8555-555555555555',repeat('a',64),(select source from e2_test_state),'en','es',1,'vocabulary',rel,l)
$$;

do $$declare role_name text;begin
 foreach role_name in array array['anon','authenticated','service_role'] loop
  if has_schema_privilege(role_name,'blab_production','USAGE')
   or has_function_privilege(role_name,'blab_production.activate(text,text,uuid[])','EXECUTE')
   then raise exception 'production operator ACL leak %',role_name; end if;
 end loop;
 if has_function_privilege('authenticated','public.production_deep_dive_dispatch(uuid,uuid,text,text,text,text,bigint,text,text,uuid)','EXECUTE')
   then raise exception 'client dispatch ACL leak';end if;
 if pg_temp.claim_production()->>'status' is distinct from 'forbidden'
   then raise exception 'production is not default closed';end if;
end$$;
select blab_production.activate(repeat('a',40),'OFFLINE MOCK evidence only',array['e2111111-1111-4111-8111-111111111111'::uuid]);
do $$declare v jsonb; l uuid;begin
 if pg_temp.claim_production(repeat('a',64),repeat('a',40),'e2222222-2222-4222-8222-222222222222')->>'status'
   is distinct from 'forbidden' then raise exception 'unlisted viewer admitted';end if;
 if pg_temp.claim_production(repeat('a',64),repeat('b',40))->>'status'
   is distinct from 'forbidden' then raise exception 'wrong release admitted';end if;
 v:=pg_temp.claim_production();
 if v->>'status' is distinct from 'claimed' or v->>'admissionClass' is distinct from 'tester'
   then raise exception 'approved viewer not admitted: %',v;end if;
 l:=(v->>'lease')::uuid;
 if pg_temp.dispatch_production(gen_random_uuid()) is distinct from false then raise exception 'stale lease admitted';end if;
 if pg_temp.dispatch_production(l) is distinct from true or pg_temp.dispatch_production(l) is distinct from false
   then raise exception 'dispatch not exactly once';end if;
 perform blab_production.deactivate((select id from blab_production.rollouts),'OFFLINE MOCK rollback only');
 if pg_temp.claim_production()->>'status' is distinct from 'forbidden'
   then raise exception 'deactivation ineffective';end if;
 if pg_temp.dispatch_production(l) is distinct from false then raise exception 'deactivated dispatch admitted';end if;
end$$;
rollback;
