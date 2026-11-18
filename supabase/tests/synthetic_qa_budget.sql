-- Run in coordinated disposable canonical140 database only. No fixtures or provider calls.
begin;
do $$
declare role_name text; sig text;
begin
foreach role_name in array array['anon','authenticated'] loop
 foreach sig in array array['public.qa_translation_scope(uuid)','public.qa_reserve_worker_slot(uuid,uuid)','public.qa_provider_dispatch(uuid,text,text,uuid,uuid,uuid)','public.claim_deep_dive_enrichment(uuid,uuid,text,text,text,text,bigint,text,boolean)'] loop
 if has_function_privilege(role_name,sig,'execute') then raise exception 'client execute leak: % %',role_name,sig;end if;
 end loop;
 if has_schema_privilege(role_name,'blab_qa','usage') then raise exception 'private schema leak';end if;
end loop;
if has_function_privilege('service_role','public.claim_deep_dive_enrichment_unbudgeted(uuid,uuid,text,text,text,text,bigint,text,boolean)','execute') then raise exception 'quota bypass';end if;
end $$;
set local role service_role;
set local request.jwt.claims='{"role":"service_role"}';
do $$
declare v jsonb;
begin
v:=public.claim_deep_dive_enrichment(gen_random_uuid(),gen_random_uuid(),repeat('a',64),repeat('b',64),'en','es',1,'vocabulary',false);
if v->>'status'<>'forbidden' then raise exception 'Deep not closed to non-QA';end if;
if public.qa_provider_dispatch(gen_random_uuid(),repeat('b',64),'base',gen_random_uuid()) is distinct from true then raise exception 'unrelated translations changed';end if;
if public.qa_provider_dispatch(gen_random_uuid(),repeat('b',64),'vocabulary',gen_random_uuid()) then raise exception 'unknown grant accepted';end if;
end $$;
rollback;
-- REQUIRED separate-session fixture proof: concurrent qa_reserve_worker_slot on same
-- fresh owned job => exactly one UUID; concurrent dispatch same nonce => one true;
-- all three kind slots => reserved32000000, total79504985; repeat/expired/wrong
-- viewer/source/closed => no grant and unchanged translation_usage/cache.
