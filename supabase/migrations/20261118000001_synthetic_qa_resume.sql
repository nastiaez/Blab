-- 141: operator-audited continuation, never a new grant or refund.
create table blab_qa.resume_permissions (
 run_id uuid primary key references blab_qa.runs,
 approval text not null check(approval='20737'),
 receipt text not null check(length(btrim(receipt)) between 16 and 2048),
 actor uuid not null, message_id uuid not null, source_hash text not null,
 context_key text not null, nonce uuid not null,
 authorized_at timestamptz not null default clock_timestamp(),
 consumed_at timestamptz, resume_lease uuid,
 check((consumed_at is null)=(resume_lease is null))
);
alter table blab_qa.resume_permissions enable row level security;
revoke all on blab_qa.resume_permissions from public,anon,authenticated,service_role;
create function blab_qa.authorize_resume(p_run uuid,p_actor uuid,p_message uuid,p_source text,p_context text,p_nonce uuid,p_approval text,p_receipt text)
returns void language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare r blab_qa.runs%rowtype;
begin
 select * into r from blab_qa.runs where id=p_run for update;
 if not found or r.state<>'closed' or r.reserved_nano<>22000000
 or exists(select 1 from blab_qa.resume_permissions where run_id=p_run)
 or not exists(select 1 from blab_qa.subjects s join public.messages m on m.id=s.message_id
   where s.run_id=p_run and s.actor=p_actor and s.base_viewer and s.message_id=p_message
   and s.chat_id=m.chat_id and s.source_hash=p_source and s.vocabulary_key=p_context
   and m.deleted_at is null and encode(digest(convert_to(btrim(m.body),'UTF8'),'sha256'),'hex')=p_source)
 or not exists(select 1 from blab_qa.slots where run_id=p_run and kind='base' and actor=p_actor and message_id=p_message and source_hash=p_source and consumed_at is not null and dispatched_at is not null)
 or not exists(select 1 from public.message_preparation_jobs where viewer_id=p_actor and message_id=p_message and source_version=p_source and status='ready')
 or not exists(select 1 from public.message_prepared_packages where viewer_id=p_actor and message_id=p_message and source_version=p_source and status='ready')
 or not exists(select 1 from blab_qa.slots where run_id=p_run and kind='vocabulary' and actor=p_actor and message_id=p_message and source_hash=p_source and context_key=p_context and nonce=p_nonce and consumed_at is not null and dispatched_at is null)
 or not exists(select 1 from blab_qa.slots where run_id=p_run and kind='correction' and consumed_at is null and nonce is null and dispatched_at is null)
 or not exists(select 1 from public.message_learning_enrichments where viewer_id=p_actor and message_id=p_message and source_hash=p_source and context_key=p_context and kind='vocabulary' and status='failed')
 then raise exception 'qa_resume_denied';end if;
 insert into blab_qa.resume_permissions(run_id,approval,receipt,actor,message_id,source_hash,context_key,nonce)
 values(p_run,p_approval,p_receipt,p_actor,p_message,p_source,p_context,p_nonce);
 update blab_qa.runs set state='open' where id=p_run;
end $$;
revoke all on function blab_qa.authorize_resume(uuid,uuid,uuid,text,text,uuid,text,text) from public,anon,authenticated,service_role;

alter function public.claim_deep_dive_enrichment(uuid,uuid,text,text,text,text,bigint,text,boolean) rename to claim_deep_dive_enrichment_budget140;
revoke all on function public.claim_deep_dive_enrichment_budget140(uuid,uuid,text,text,text,text,bigint,text,boolean) from public,anon,authenticated,service_role;
create function public.claim_deep_dive_enrichment(p_viewer uuid,p_message uuid,p_context text,p_source text,p_known text,p_target text,p_revision bigint,p_kind text,p_retry boolean default false)
returns jsonb language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare a blab_qa.resume_permissions%rowtype; e public.message_learning_enrichments%rowtype; l uuid;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
 perform 1 from blab_qa.runs r join blab_qa.subjects s on s.run_id=r.id where s.actor=p_viewer for update of r;
 select * into a from blab_qa.resume_permissions where actor=p_viewer and message_id=p_message and context_key=p_context and source_hash=p_source for update;
 if found and a.consumed_at is null and p_kind='vocabulary' then
  select * into e from public.message_learning_enrichments where viewer_id=p_viewer and context_key=p_context for update;
  if not found or e.status<>'failed' or e.message_id<>p_message or e.source_hash<>p_source or e.kind<>p_kind or e.known_lang<>p_known or e.target_lang<>p_target or e.language_revision<>p_revision
  or not public.deep_dive_context_allowed(p_viewer,p_message,p_source,p_known,p_target,p_revision,p_kind)
  or not exists(select 1 from blab_qa.runs where id=a.run_id and state='open' and reserved_nano=22000000)
  or not exists(select 1 from blab_qa.subjects where run_id=a.run_id and actor=p_viewer and base_viewer and message_id=p_message and source_hash=p_source and vocabulary_key=p_context)
  or not exists(select 1 from blab_qa.slots where run_id=a.run_id and kind='vocabulary' and nonce=a.nonce and actor=p_viewer and message_id=p_message and source_hash=p_source and context_key=p_context and consumed_at is not null and dispatched_at is null)
  then return jsonb_build_object('status','forbidden');end if;
  l:=gen_random_uuid();
  update blab_qa.resume_permissions set consumed_at=clock_timestamp(),resume_lease=l where run_id=a.run_id;
  update public.message_learning_enrichments set status='processing',lease_token=l,locked_until=clock_timestamp()+interval '60 seconds',payload=null,expires_at=clock_timestamp()+interval '24 hours',updated_at=clock_timestamp() where viewer_id=p_viewer and context_key=p_context;
  return jsonb_build_object('status','claimed','lease',l,'qaNonce',a.nonce);
 end if;
 return public.claim_deep_dive_enrichment_budget140(p_viewer,p_message,p_context,p_source,p_known,p_target,p_revision,p_kind,p_retry);
end $$;
revoke all on function public.claim_deep_dive_enrichment(uuid,uuid,text,text,text,text,bigint,text,boolean) from public,anon,authenticated;
grant execute on function public.claim_deep_dive_enrichment(uuid,uuid,text,text,text,text,bigint,text,boolean) to service_role;

-- Audit identity is append-only; consumed permission can never be reset.
create function blab_qa.fence_resume_receipt() returns trigger language plpgsql set search_path=pg_catalog as $$
begin
 if tg_op='DELETE' then raise exception 'qa_resume_receipt_immutable';end if;
 if old.consumed_at is not null or new.run_id is distinct from old.run_id
 or new.approval is distinct from old.approval or new.receipt is distinct from old.receipt
 or new.actor is distinct from old.actor or new.message_id is distinct from old.message_id
 or new.source_hash is distinct from old.source_hash or new.context_key is distinct from old.context_key
 or new.nonce is distinct from old.nonce or new.authorized_at is distinct from old.authorized_at
 or new.consumed_at is null or new.resume_lease is null then raise exception 'qa_resume_receipt_immutable';end if;
 return new;
end $$;
revoke all on function blab_qa.fence_resume_receipt() from public,anon,authenticated,service_role;
create trigger fence_resume_receipt before update or delete on blab_qa.resume_permissions for each row execute function blab_qa.fence_resume_receipt();

-- Recompile the hosted caller after the canonical OID rename on live upgrades.
create or replace function public.claim_hosted_qa_deep_dive_enrichment(p_viewer uuid,p_message uuid,p_context text,p_source text,p_known text,p_target text,p_revision bigint,p_kind text,p_retry boolean default false) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
begin
if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
if not exists(select 1 from blab_qa.subjects s join blab_qa.runs r on r.id=s.run_id where s.actor=p_viewer and s.base_viewer and s.message_id=p_message and s.source_hash=p_source and r.state='open' and case p_kind when 'vocabulary' then s.vocabulary_key=p_context when 'correction' then s.correction_key=p_context else false end) then return jsonb_build_object('status','forbidden');end if;
return public.claim_deep_dive_enrichment(p_viewer,p_message,p_context,p_source,p_known,p_target,p_revision,p_kind,false);
end $$;
revoke all on function public.claim_hosted_qa_deep_dive_enrichment(uuid,uuid,text,text,text,text,bigint,text,boolean) from public,anon,authenticated;
grant execute on function public.claim_hosted_qa_deep_dive_enrichment(uuid,uuid,text,text,text,text,bigint,text,boolean) to service_role;
