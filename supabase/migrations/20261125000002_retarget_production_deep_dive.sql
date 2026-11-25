-- Preserve historical rollout records; never transfer or activate an approval.
alter table blab_production.rollouts drop constraint rollouts_project_check;
alter table blab_production.rollouts add constraint rollouts_project_check
  check (project in ('bhzcexhebjszwyqvcsxs', 'lwsscssuktjlmiqryfnq'));

create or replace function blab_production.activate(p_revision text,p_evidence text,p_viewers uuid[]) returns uuid
language plpgsql security definer set search_path=public,pg_temp as $$
declare result uuid;
begin
 perform pg_advisory_xact_lock(hashtextextended('production-deep-rollout',0));
 insert into blab_production.rollouts(project,revision,approval_evidence,viewers)
 values('lwsscssuktjlmiqryfnq',p_revision,p_evidence,p_viewers) returning id into result;
 return result;
end $$;

create or replace function public.claim_production_deep_dive_enrichment(p_viewer uuid,p_message uuid,p_context text,p_source text,p_known text,p_target text,p_revision bigint,p_kind text,p_release text,p_retry boolean default false)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v jsonb;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
 -- Synthetic QA identities and fixtures never enter the production rollout.
 if not blab_production.nonqa(p_viewer,p_message) then return jsonb_build_object('status','forbidden');end if;
 perform 1 from blab_production.rollouts where project='lwsscssuktjlmiqryfnq' and revision=p_release and p_viewer=any(viewers) and deactivated_at is null for share;
 if not found or not blab_production.eligible(p_viewer) then return jsonb_build_object('status','forbidden');end if;
 v:=public.claim_deep_dive_enrichment(p_viewer,p_message,p_context,p_source,p_known,p_target,p_revision,p_kind,p_retry);
 return v||jsonb_build_object('admissionClass','tester');
end $$;

create or replace function public.production_deep_dive_dispatch(p_viewer uuid,p_message uuid,p_context text,p_source text,p_known text,p_target text,p_revision bigint,p_kind text,p_release text,p_lease uuid)
returns boolean language plpgsql security definer set search_path=public,pg_temp as $$
declare r uuid;e public.message_learning_enrichments%rowtype;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
 select id into r from blab_production.rollouts where project='lwsscssuktjlmiqryfnq' and revision=p_release and p_viewer=any(viewers) and deactivated_at is null for share;
 if not found or not blab_production.nonqa(p_viewer,p_message) or not blab_production.eligible(p_viewer) then return false;end if;
 select * into e from public.message_learning_enrichments where viewer_id=p_viewer and context_key=p_context for update;
 if not found or p_lease is null or e.status<>'processing' or e.lease_token is distinct from p_lease
 or e.locked_until is null or e.expires_at is null
 or e.locked_until<=clock_timestamp() or e.expires_at<=clock_timestamp()
 or e.message_id is distinct from p_message or e.source_hash is distinct from p_source
 or e.known_lang is distinct from p_known or e.target_lang is distinct from p_target
 or e.language_revision is distinct from p_revision or e.kind is distinct from p_kind
 or not public.deep_dive_context_allowed(p_viewer,p_message,p_source,p_known,p_target,p_revision,p_kind) then return false;end if;
 insert into blab_production.dispatches(lease,rollout,viewer_id,message_id,context_key,source_hash,known_lang,target_lang,language_revision,kind)
 values(p_lease,r,p_viewer,p_message,p_context,p_source,p_known,p_target,p_revision,p_kind) on conflict(lease) do nothing;
 return found;
end $$;
