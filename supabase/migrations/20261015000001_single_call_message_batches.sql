-- One lease group per message/source, with both viewer jobs claimed together.
-- Existing per-viewer revision/source checks and completion functions remain authoritative.
create or replace function public.claim_message_preparation_jobs_for_worker(p_limit integer default 10)
returns setof public.message_preparation_jobs
language plpgsql security definer set search_path=public,extensions as $$
declare v_capacity integer; v_used integer := 0; g record;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 if not pg_try_advisory_xact_lock(hashtext('blab_message_preparation_claim')) then return; end if;
 update public.message_preparation_jobs set status=case when attempts>=4 then 'failed' else 'queued' end,
   locked_at=null,lease_token=null,available_at=now(),last_error='lease_expired'
 where status='processing' and locked_at<now()-interval '45 seconds';
 select greatest(0,4-count(*))::integer into v_capacity from public.message_preparation_jobs where status='processing';
 for g in
  select j.message_id,j.source_version,count(*)::integer as n,min(m.created_at) as sent
  from public.message_preparation_jobs j join public.messages m on m.id=j.message_id
  where j.status='queued'
   and not exists(select 1 from public.message_preparation_jobs busy where busy.message_id=j.message_id and busy.status='processing')
  group by j.message_id,j.source_version
  having max(j.available_at)<=now()
  order by sent,j.message_id
 loop
  exit when v_used>=greatest(1,least(coalesce(p_limit,10),20));
  if g.n>v_capacity then continue; end if;
  return query update public.message_preparation_jobs j set status='processing',locked_at=now(),
    lease_token=gen_random_uuid(),attempts=j.attempts+1
  where j.message_id=g.message_id and j.source_version=g.source_version and j.status='queued' returning j.*;
  v_capacity:=v_capacity-g.n; v_used:=v_used+g.n;
 end loop;
end; $$;
revoke all on function public.claim_message_preparation_jobs_for_worker(integer) from public,anon,authenticated;
grant execute on function public.claim_message_preparation_jobs_for_worker(integer) to service_role;

create or replace function public.complete_translation_message_batch(p_results jsonb)
returns boolean language plpgsql security definer set search_path=public,extensions as $$
declare r jsonb; v_message uuid; j public.message_preparation_jobs%rowtype;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 if jsonb_typeof(p_results)<>'array' or jsonb_array_length(p_results) not between 1 and 4 then raise exception 'invalid_batch'; end if;
 -- Transactional: a stale viewer must not leave a half-written group.
 for r in select value from jsonb_array_elements(p_results) order by value->>'jobId' loop
  select * into j from public.message_preparation_jobs where id=(r->>'jobId')::uuid
    and lease_token=(r->>'lease')::uuid and status='processing' for update;
  if not found then raise exception 'stale_batch'; end if;
  if v_message is not null and v_message<>j.message_id then raise exception 'mixed_batch'; end if;
  v_message:=j.message_id;
  if public.leased_translation_action(j.id,j.lease_token,'readable',jsonb_build_object('result',(r->'result')-'tokens','contractVersion',r->'result'->>'contractVersion'))<>'true'::jsonb then raise exception 'stale_readable'; end if;
  if public.leased_translation_action(j.id,j.lease_token,'complete',r->'result')<>'true'::jsonb then raise exception 'stale_completion'; end if;
 end loop;
 return true;
end; $$;
revoke all on function public.complete_translation_message_batch(jsonb) from public,anon,authenticated;
grant execute on function public.complete_translation_message_batch(jsonb) to service_role;
