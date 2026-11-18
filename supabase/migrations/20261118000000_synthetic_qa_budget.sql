-- 140: operator-only QA policy, immutable kind reservations; no seeded actors.
create schema blab_qa;
revoke all on schema blab_qa from public,anon,authenticated,service_role;
create table blab_qa.runs(id uuid primary key,project text not null check(project='tpfksdljkfnenjfdbane'),state text not null check(state in ('open','closed')),initial_nano bigint not null default 47504985 check(initial_nano=47504985),cap_nano bigint not null default 80000000 check(cap_nano=80000000),reserved_nano bigint not null default 0 check(reserved_nano between 0 and 32000000),check(initial_nano+reserved_nano<=cap_nano));
create table blab_qa.actors(actor uuid primary key);
create table blab_qa.subjects(actor uuid primary key,run_id uuid not null references blab_qa.runs,chat_id uuid not null,message_id uuid not null,source_hash text not null check(source_hash ~ '^[0-9a-f]{64}$'),base_viewer boolean not null default false,vocabulary_key text,correction_key text);
create unique index qa_one_base_viewer on blab_qa.subjects(run_id) where base_viewer;
create table blab_qa.slots(run_id uuid not null references blab_qa.runs,kind text not null check(kind in ('base','vocabulary','correction')),reservation_nano bigint not null,consumed_at timestamptz,dispatched_at timestamptz,nonce uuid unique,actor uuid,message_id uuid,source_hash text,context_key text,job_id uuid,lease uuid,primary key(run_id,kind),check(reservation_nano=case when kind='base' then 12000000 else 10000000 end));
revoke all on all tables in schema blab_qa from public,anon,authenticated,service_role;
alter table blab_qa.actors enable row level security;
alter table blab_qa.runs enable row level security;
alter table blab_qa.subjects enable row level security;
alter table blab_qa.slots enable row level security;
create function public.qa_translation_scope(p_message uuid) returns boolean language sql security definer set search_path=public,pg_temp as $$
select exists(select 1 from blab_qa.subjects s join public.messages m on m.id=p_message where s.message_id=m.id or s.chat_id=m.chat_id or s.actor=m.sender_id) or exists(select 1 from blab_qa.actors a join public.messages m on m.id=p_message where m.sender_id=a.actor) or exists(select 1 from blab_qa.actors a join public.message_preparation_jobs j on j.viewer_id=a.actor where j.message_id=p_message)
$$;
create function public.qa_reserve_slot(p_viewer uuid,p_message uuid,p_source text,p_kind text,p_context text,p_job uuid default null,p_lease uuid default null) returns uuid language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare s blab_qa.subjects%rowtype;r blab_qa.runs%rowtype;n uuid;c bigint;
begin
if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
select * into s from blab_qa.subjects where actor=p_viewer;
if not found then raise exception 'qa_policy_denied';end if;
select * into r from blab_qa.runs where id=s.run_id for update;
if r.state<>'open' or not s.base_viewer or s.message_id<>p_message or s.source_hash<>p_source or not exists(select 1 from public.messages m where m.id=p_message and m.chat_id=s.chat_id and m.deleted_at is null and encode(digest(convert_to(btrim(m.body),'UTF8'),'sha256'),'hex')=p_source) then raise exception 'qa_policy_denied';end if;
if p_kind='base' then
perform 1 from public.message_preparation_jobs where id=p_job and viewer_id=p_viewer and message_id=p_message and source_version=p_source and status='processing' and lease_token=p_lease and locked_at>clock_timestamp()-interval '45 seconds' for update;
if not found then raise exception 'qa_lease_denied';end if;
elsif (p_kind='vocabulary' and s.vocabulary_key=p_context) or (p_kind='correction' and s.correction_key=p_context) then
if not exists(select 1 from blab_qa.slots where run_id=r.id and kind='base' and dispatched_at is not null) then raise exception 'qa_base_required';end if;
else raise exception 'qa_policy_denied';end if;
n:=gen_random_uuid();
update blab_qa.slots set consumed_at=clock_timestamp(),nonce=n,actor=p_viewer,message_id=p_message,source_hash=p_source,context_key=p_context,job_id=p_job,lease=p_lease where run_id=r.id and kind=p_kind and consumed_at is null returning reservation_nano into c;
if not found then raise exception 'qa_slot_consumed';end if;
update blab_qa.runs set reserved_nano=reserved_nano+c where id=r.id;
return n;
end $$;
alter function public.claim_deep_dive_enrichment(uuid,uuid,text,text,text,text,bigint,text,boolean) rename to claim_deep_dive_enrichment_unbudgeted;
create function public.claim_deep_dive_enrichment(p_viewer uuid,p_message uuid,p_context text,p_source text,p_known text,p_target text,p_revision bigint,p_kind text,p_retry boolean default false) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v jsonb;n uuid;
begin
if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
-- Unscoped canonical local callers retain the original quota/cache/retry behavior.
if not public.qa_translation_scope(p_message) and not exists(select 1 from blab_qa.actors where actor=p_viewer) and not exists(select 1 from blab_qa.subjects where actor=p_viewer) then
return public.claim_deep_dive_enrichment_unbudgeted(p_viewer,p_message,p_context,p_source,p_known,p_target,p_revision,p_kind,p_retry);
end if;
if not exists(select 1 from blab_qa.subjects s join blab_qa.runs r on r.id=s.run_id where s.actor=p_viewer and s.base_viewer and s.message_id=p_message and s.source_hash=p_source and r.state='open' and case p_kind when 'vocabulary' then s.vocabulary_key=p_context when 'correction' then s.correction_key=p_context else false end) then return jsonb_build_object('status','forbidden');end if;
v:=public.claim_deep_dive_enrichment_unbudgeted(p_viewer,p_message,p_context,p_source,p_known,p_target,p_revision,p_kind,false);
if v->>'status'='claimed' then
n:=public.qa_reserve_slot(p_viewer,p_message,p_source,p_kind,p_context);
v:=v||jsonb_build_object('qaNonce',n);
end if;
return v;
end $$;
-- Hosted admission is strict even before any QA policy is seeded.
create function public.claim_hosted_qa_deep_dive_enrichment(p_viewer uuid,p_message uuid,p_context text,p_source text,p_known text,p_target text,p_revision bigint,p_kind text,p_retry boolean default false) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
if not exists(select 1 from blab_qa.subjects s join blab_qa.runs r on r.id=s.run_id where s.actor=p_viewer and s.base_viewer and s.message_id=p_message and s.source_hash=p_source and r.state='open' and case p_kind when 'vocabulary' then s.vocabulary_key=p_context when 'correction' then s.correction_key=p_context else false end) then return jsonb_build_object('status','forbidden');end if;
return public.claim_deep_dive_enrichment(p_viewer,p_message,p_context,p_source,p_known,p_target,p_revision,p_kind,false);
end $$;
revoke all on function public.claim_hosted_qa_deep_dive_enrichment(uuid,uuid,text,text,text,text,bigint,text,boolean) from public,anon,authenticated;
grant execute on function public.claim_hosted_qa_deep_dive_enrichment(uuid,uuid,text,text,text,text,bigint,text,boolean) to service_role;
revoke all on function public.claim_deep_dive_enrichment_unbudgeted(uuid,uuid,text,text,text,text,bigint,text,boolean) from public,anon,authenticated,service_role;
create function public.qa_provider_dispatch(p_message uuid,p_source text,p_kind text,p_nonce uuid,p_job uuid default null,p_lease uuid default null) returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare r uuid;
begin
if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
if p_kind='direct' then return not public.qa_translation_scope(p_message);end if;
if p_kind='base' and not public.qa_translation_scope(p_message) then return true;end if;
select run_id into r from blab_qa.slots where nonce=p_nonce;
perform 1 from blab_qa.runs where id=r and state='open' for update;
if not found then return false;end if;
if p_kind='base' then
perform 1 from public.message_preparation_jobs j join blab_qa.slots slot on slot.run_id=r and slot.kind='base' and slot.nonce=p_nonce and slot.job_id=j.id and slot.lease=j.lease_token and slot.actor=j.viewer_id and slot.message_id=j.message_id and slot.source_hash=j.source_version where j.id=p_job and j.lease_token=p_lease and j.message_id=p_message and j.source_version=p_source and j.status='processing' and j.locked_at>clock_timestamp()-interval '45 seconds' for update of j;
if not found then return false;end if;
end if;
update blab_qa.slots set dispatched_at=clock_timestamp() where run_id=r and kind=p_kind and nonce=p_nonce and message_id=p_message and source_hash=p_source and dispatched_at is null and (p_kind<>'base' or (job_id=p_job and lease=p_lease));
return found;
end $$;
revoke all on function public.qa_translation_scope(uuid) from public,anon,authenticated;
revoke all on function public.qa_reserve_slot(uuid,uuid,text,text,text,uuid,uuid) from public,anon,authenticated;
revoke all on function public.qa_provider_dispatch(uuid,text,text,uuid,uuid,uuid) from public,anon,authenticated;
revoke all on function public.claim_deep_dive_enrichment(uuid,uuid,text,text,text,text,bigint,text,boolean) from public,anon,authenticated;
grant execute on function public.qa_translation_scope(uuid),public.qa_reserve_slot(uuid,uuid,text,text,text,uuid,uuid),public.qa_provider_dispatch(uuid,text,text,uuid,uuid,uuid),public.claim_deep_dive_enrichment(uuid,uuid,text,text,text,text,bigint,text,boolean) to service_role;

create function public.qa_reserve_worker_slot(p_job uuid,p_lease uuid) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare j public.message_preparation_jobs%rowtype;
begin
if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
select * into j from public.message_preparation_jobs where id=p_job;
if not found then raise exception 'qa_lease_denied';end if;
return public.qa_reserve_slot(j.viewer_id,j.message_id,j.source_version,'base',null,p_job,p_lease);
end $$;
revoke all on function public.qa_reserve_worker_slot(uuid,uuid) from public,anon,authenticated;
grant execute on function public.qa_reserve_worker_slot(uuid,uuid) to service_role;
-- Fence late publication after closure and prevent scheduler retries for QA failures.
create function public.qa_fence_jobs() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
if public.qa_translation_scope(new.message_id) then
 if new.status='queued' and old.status='processing' then new.status:='failed';end if;
 if new.status='ready' and not exists(select 1 from blab_qa.subjects s join blab_qa.runs r on r.id=s.run_id where s.actor=new.viewer_id and s.base_viewer and s.message_id=new.message_id and s.source_hash=new.source_version and r.state='open') then raise exception 'qa_closed';end if;
end if;
return new;
end $$;
revoke all on function public.qa_fence_jobs() from public,anon,authenticated,service_role;
create trigger qa_fence_jobs before update on public.message_preparation_jobs for each row execute function public.qa_fence_jobs();

-- Every failed attempt closes remaining slots. Ready writes are fenced at storage boundary.
create function public.qa_fence_package() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
if public.qa_translation_scope(new.message_id) and new.status='ready' then
 perform 1 from blab_qa.runs r join blab_qa.subjects s on s.run_id=r.id where r.state='open' and s.base_viewer and s.actor=new.viewer_id and s.message_id=new.message_id and s.source_hash=new.source_version for update of r;
 if not found then raise exception 'qa_publication_denied';end if;
end if;return new;
end $$;
revoke all on function public.qa_fence_package() from public,anon,authenticated,service_role;
create trigger qa_fence_package before insert or update on public.message_prepared_packages for each row execute function public.qa_fence_package();
create function public.qa_close_failure() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
if new.status='failed' then update blab_qa.runs r set state='closed' where exists(select 1 from blab_qa.subjects s where s.run_id=r.id and s.message_id=new.message_id and s.actor=new.viewer_id and s.base_viewer);end if;
return new;
end $$;
revoke all on function public.qa_close_failure() from public,anon,authenticated,service_role;
create trigger qa_close_worker_failure after update on public.message_preparation_jobs for each row execute function public.qa_close_failure();
create trigger qa_close_deep_failure after update on public.message_learning_enrichments for each row execute function public.qa_close_failure();
create function public.qa_fence_enrichment() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
if public.qa_translation_scope(new.message_id) and new.status='ready' then
 perform 1 from blab_qa.runs r join blab_qa.subjects s on s.run_id=r.id where r.state='open' and s.actor=new.viewer_id and s.message_id=new.message_id for update of r;
 if not found then raise exception 'qa_publication_denied';end if;
end if;return new;
end $$;
revoke all on function public.qa_fence_enrichment() from public,anon,authenticated,service_role;
create trigger qa_fence_enrichment before update on public.message_learning_enrichments for each row execute function public.qa_fence_enrichment();

create function public.qa_worker_allowed(p_job uuid) returns boolean language sql security definer set search_path=public,pg_temp as $$
select exists(select 1 from public.message_preparation_jobs j join blab_qa.subjects s on s.actor=j.viewer_id and s.message_id=j.message_id and s.source_hash=j.source_version join blab_qa.runs r on r.id=s.run_id where j.id=p_job and s.base_viewer and r.state='open')
$$;
revoke all on function public.qa_worker_allowed(uuid) from public,anon,authenticated;
grant execute on function public.qa_worker_allowed(uuid) to service_role;
