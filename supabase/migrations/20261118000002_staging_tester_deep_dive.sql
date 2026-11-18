-- 142: default closed, operator-only staging release receipt. No activation seed.
create schema blab_staging;
revoke all on schema blab_staging from public,anon,authenticated,service_role;
create table blab_staging.rollouts(
 id uuid primary key default gen_random_uuid(),
 project text not null check(project='tpfksdljkfnenjfdbane'),
 revision text not null check(revision ~ '^[0-9a-f]{40}$'),
 approval_evidence text not null check(length(btrim(approval_evidence)) between 16 and 4096),
 activated_at timestamptz not null default clock_timestamp(),
 deactivated_at timestamptz,
 deactivation_evidence text,
 check((deactivated_at is null)=(deactivation_evidence is null))
);
create unique index staging_one_active on blab_staging.rollouts(project) where deactivated_at is null;
create table blab_staging.dispatches(
 lease uuid primary key, rollout uuid not null references blab_staging.rollouts,
 viewer_id uuid not null, message_id uuid not null, context_key text not null,
 source_hash text not null, known_lang text not null,target_lang text not null,
 language_revision bigint not null,kind text not null,
 dispatched_at timestamptz not null default clock_timestamp()
);
alter table blab_staging.rollouts enable row level security;
alter table blab_staging.dispatches enable row level security;
revoke all on all tables in schema blab_staging from public,anon,authenticated,service_role;
create function blab_staging.activate(p_revision text,p_evidence text) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare result uuid;
begin
 perform pg_advisory_xact_lock(hashtextextended('staging-deep-rollout',0));
 if exists(select 1 from blab_qa.runs where state<>'closed') then raise exception 'qa_closure_required';end if;
 insert into blab_staging.rollouts(project,revision,approval_evidence)
 values('tpfksdljkfnenjfdbane',p_revision,p_evidence) returning id into result;
 return result;
end $$;
create function blab_staging.deactivate(p_id uuid,p_evidence text) returns void
language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if length(btrim(p_evidence)) not between 16 and 4096 or p_evidence is null then raise exception 'evidence_required';end if;
 update blab_staging.rollouts set deactivated_at=clock_timestamp(),deactivation_evidence=p_evidence where id=p_id and deactivated_at is null;
 if not found then raise exception 'active_rollout_required';end if;
end $$;
revoke all on function blab_staging.activate(text,text),blab_staging.deactivate(uuid,text) from public,anon,authenticated,service_role;
create function blab_staging.nonqa(p_viewer uuid,p_message uuid) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select not public.qa_translation_scope(p_message)
 and not exists(select 1 from blab_qa.actors where actor=p_viewer)
 and not exists(select 1 from blab_qa.subjects where actor=p_viewer)
$$;
create function blab_staging.eligible(p_viewer uuid) returns boolean
language sql stable security definer set search_path=public,pg_temp as $$
 select exists(select 1 from public.app_distribution_policy where singleton and channel='test'
 and testing_enabled and (testing_expires_at is null or testing_expires_at>clock_timestamp()))
 and public.has_distribution_access(p_viewer) and public.is_account_active(p_viewer)
 and public.has_live_account_identity(p_viewer)
$$;
revoke all on function blab_staging.nonqa(uuid,uuid),blab_staging.eligible(uuid) from public,anon,authenticated,service_role;
create function public.claim_hosted_deep_dive_enrichment(p_viewer uuid,p_message uuid,p_context text,p_source text,p_known text,p_target text,p_revision bigint,p_kind text,p_release text,p_retry boolean default false)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v jsonb;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
 -- QA identity/message/chat always wins, including closed actor tombstones.
 if not blab_staging.nonqa(p_viewer,p_message) then
  return public.claim_hosted_qa_deep_dive_enrichment(p_viewer,p_message,p_context,p_source,p_known,p_target,p_revision,p_kind,false)||jsonb_build_object('admissionClass','qa');
 end if;
 perform 1 from blab_staging.rollouts where project='tpfksdljkfnenjfdbane' and revision=p_release and deactivated_at is null for share;
 if not found or not blab_staging.eligible(p_viewer) then return jsonb_build_object('status','forbidden');end if;
 v:=public.claim_deep_dive_enrichment(p_viewer,p_message,p_context,p_source,p_known,p_target,p_revision,p_kind,p_retry);
 return v||jsonb_build_object('admissionClass','tester');
end $$;
create function public.staging_deep_dive_dispatch(p_viewer uuid,p_message uuid,p_context text,p_source text,p_known text,p_target text,p_revision bigint,p_kind text,p_release text,p_lease uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare r uuid;e public.message_learning_enrichments%rowtype;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
 select id into r from blab_staging.rollouts where project='tpfksdljkfnenjfdbane' and revision=p_release and deactivated_at is null for share;
 if not found or not blab_staging.nonqa(p_viewer,p_message) or not blab_staging.eligible(p_viewer) then return false;end if;
 select * into e from public.message_learning_enrichments where viewer_id=p_viewer and context_key=p_context for update;
 if not found or e.status<>'processing' or e.lease_token is distinct from p_lease
 or e.locked_until<=clock_timestamp() or e.expires_at<=clock_timestamp()
 or e.message_id is distinct from p_message or e.source_hash is distinct from p_source
 or e.known_lang is distinct from p_known or e.target_lang is distinct from p_target
 or e.language_revision is distinct from p_revision or e.kind is distinct from p_kind
 or not public.deep_dive_context_allowed(p_viewer,p_message,p_source,p_known,p_target,p_revision,p_kind) then return false;end if;
 insert into blab_staging.dispatches(lease,rollout,viewer_id,message_id,context_key,source_hash,known_lang,target_lang,language_revision,kind)
 values(p_lease,r,p_viewer,p_message,p_context,p_source,p_known,p_target,p_revision,p_kind) on conflict(lease) do nothing;
 return found;
end $$;
revoke all on function public.claim_hosted_deep_dive_enrichment(uuid,uuid,text,text,text,text,bigint,text,text,boolean),public.staging_deep_dive_dispatch(uuid,uuid,text,text,text,text,bigint,text,text,uuid) from public,anon,authenticated;
grant execute on function public.claim_hosted_deep_dive_enrichment(uuid,uuid,text,text,text,text,bigint,text,text,boolean),public.staging_deep_dive_dispatch(uuid,uuid,text,text,text,text,bigint,text,text,uuid) to service_role;
create function blab_staging.fence_audit() returns trigger language plpgsql set search_path=pg_catalog as $$
begin
 if tg_table_name='dispatches' or tg_op='DELETE' then raise exception 'staging_audit_immutable';end if;
 if old.deactivated_at is not null or new.id is distinct from old.id
 or new.project is distinct from old.project or new.revision is distinct from old.revision
 or new.approval_evidence is distinct from old.approval_evidence
 or new.activated_at is distinct from old.activated_at
 or new.deactivated_at is null or new.deactivation_evidence is null
 then raise exception 'staging_audit_immutable';end if;
 return new;
end $$;
revoke all on function blab_staging.fence_audit() from public,anon,authenticated,service_role;
create trigger staging_rollout_audit before update or delete on blab_staging.rollouts for each row execute function blab_staging.fence_audit();
create trigger staging_dispatch_audit before update or delete on blab_staging.dispatches for each row execute function blab_staging.fence_audit();
