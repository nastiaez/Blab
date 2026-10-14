alter table public.message_preparation_jobs add column lease_token uuid;

create or replace function public.claim_message_preparation_jobs_for_worker(p_limit integer default 10)
returns setof public.message_preparation_jobs
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_sentence integer;
  v_metadata integer;
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  if not pg_try_advisory_xact_lock(hashtext('blab_message_preparation_claim')) then return; end if;
  -- Every completion is fenced by a per-claim token. A dead worker cannot overwrite a reclaimed job.
  update public.message_preparation_jobs
  set status = case when attempts >= 4 then 'failed' else 'queued' end, locked_at = null, available_at = now(), last_error = 'lease_expired'
  where status = 'processing' and locked_at < now() - interval '45 seconds';
  select greatest(0, 3 - count(*) filter (where phase = 'sentence'))::integer,
         greatest(0, 1 - count(*) filter (where phase = 'word_help'))::integer
  into v_sentence, v_metadata from public.message_preparation_jobs where status = 'processing';
  return query
  with candidates as (
    select j.id, j.phase, m.created_at as message_created_at,
      row_number() over (partition by j.phase order by m.created_at, m.id, j.created_at, j.id) as rank
    from public.message_preparation_jobs j join public.messages m on m.id = j.message_id
    where j.status = 'queued' and j.available_at <= now()
  ), picked as (
    select j.id from candidates c join public.message_preparation_jobs j on j.id = c.id
    where c.rank <= case c.phase when 'sentence' then v_sentence else v_metadata end
    order by c.phase = 'word_help', c.message_created_at, c.id
    limit greatest(1, least(coalesce(p_limit, 10), 20))
    for update of j skip locked
  )
  update public.message_preparation_jobs j
  set status = 'processing', locked_at = now(), lease_token = gen_random_uuid(), attempts = j.attempts + 1
  from picked where j.id = picked.id returning j.*;
end;
$$;
revoke all on function public.claim_message_preparation_jobs_for_worker(integer) from public, anon, authenticated;
grant execute on function public.claim_message_preparation_jobs_for_worker(integer) to service_role;


create or replace function public.leased_translation_action(
  p_job_id uuid, p_lease_token uuid, p_action text, p_payload jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path = public, extensions
as $$
declare j public.message_preparation_jobs%rowtype;
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  select * into j from public.message_preparation_jobs
    where id = p_job_id and status = 'processing' and lease_token = p_lease_token
    for update;
  if not found then
    if p_action = 'prepare' then return jsonb_build_object('status','stale'); end if;
    return 'false'::jsonb;
  end if;
  if p_action = 'prepare' then return public.request_message_translation_job(j.id); end if;
  if p_action = 'readable' then
    return to_jsonb(public.publish_message_readable_variant(j.message_id,j.viewer_id,
      j.learning_language,j.primary_known_language,j.language_revision::integer,
      j.source_version,p_payload->'result',p_payload->>'contractVersion'));
  end if;
  if p_action = 'word_help' then return to_jsonb(public.yield_message_word_help(j.id)); end if;
  if p_action = 'complete' then
    return to_jsonb(public.complete_message_translation_job(j.id,
      p_payload->>'translation',p_payload->>'interfaceText',p_payload->>'sourceLang',
      p_payload->>'mode',p_payload->>'explanation',p_payload->>'confidence',
      p_payload->'tokens',nullif(p_payload->'formAlternatives','null'::jsonb),p_payload->>'contractVersion'));
  end if;
  if p_action = 'finish' then
    return to_jsonb(public.finish_message_preparation_job(j.id,p_payload->>'outcome',
      p_payload->>'reason',coalesce((p_payload->>'delaySeconds')::integer,0)));
  end if;
  raise exception 'invalid_translation_action';
end;
$$;
revoke all on function public.leased_translation_action(uuid,uuid,text,jsonb) from public,anon,authenticated;
grant execute on function public.leased_translation_action(uuid,uuid,text,jsonb) to service_role;

select cron.unschedule(jobid) from cron.job where jobname='blab-message-preparation-recovery';
select cron.schedule('blab-message-preparation-recovery','2 seconds',
  $cron$select private.request_message_preparation_worker()
  where exists(select 1 from public.message_preparation_jobs
    where (status='queued' and available_at<=now())
       or (status='processing' and locked_at<now()-interval '45 seconds'))$cron$);
