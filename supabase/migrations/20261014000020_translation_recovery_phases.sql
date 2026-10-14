-- Sentence capacity must not be occupied by optional word-help work.
alter table public.message_preparation_jobs
  add column phase text not null default 'sentence'
  check (phase in ('sentence', 'word_help'));

create or replace function public.yield_message_word_help(p_job_id uuid)
returns boolean language plpgsql security definer set search_path = public
as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  update public.message_preparation_jobs j
  set phase = 'word_help', status = 'queued', attempts = 0,
      locked_at = null, available_at = now(), last_error = null
  where j.id = p_job_id and j.status = 'processing' and j.phase = 'sentence'
    and exists (select 1 from public.message_readable_variants r
      where r.message_id = j.message_id and r.viewer_id = j.viewer_id
        and r.source_hash = j.source_version
        and r.language_revision = j.language_revision
        and r.target_lang = j.learning_language
        and r.interface_lang = j.primary_known_language);
  return found;
end;
$$;
revoke all on function public.yield_message_word_help(uuid) from public, anon, authenticated;
grant execute on function public.yield_message_word_help(uuid) to service_role;

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
  -- Retain the conservative lease until token-fenced completion is deployed.
  update public.message_preparation_jobs
  set status = 'queued', locked_at = null, available_at = now(), last_error = 'lease_expired'
  where status = 'processing' and locked_at < now() - interval '5 minutes';
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
  set status = 'processing', locked_at = now(), attempts = j.attempts + 1
  from picked where j.id = picked.id returning j.*;
end;
$$;
revoke all on function public.claim_message_preparation_jobs_for_worker(integer) from public, anon, authenticated;
grant execute on function public.claim_message_preparation_jobs_for_worker(integer) to service_role;

-- Wake due work promptly, but do not invoke an idle worker every two seconds.
select cron.unschedule(jobid) from cron.job where jobname = 'blab-message-preparation-recovery';
select cron.schedule('blab-message-preparation-recovery', '2 seconds',
  $cron$select private.request_message_preparation_worker()
    where exists (select 1 from public.message_preparation_jobs
      where (status = 'queued' and available_at <= now())
         or (status = 'processing' and locked_at < now() - interval '5 minutes'))$cron$);


-- Respect upstream Retry-After instead of truncating it to five minutes.
create or replace function public.finish_message_preparation_job(
  p_job_id uuid,
  p_outcome text,
  p_error text,
  p_delay_seconds integer default 0
) returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_job public.message_preparation_jobs%rowtype;
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  select * into v_job
  from public.message_preparation_jobs
  where id = p_job_id and status = 'processing'
  for update;
  if not found then return false; end if;
  if p_outcome = 'retry' then
    update public.message_preparation_jobs
    set status = 'queued',
        available_at = now() + make_interval(secs => greatest(1, p_delay_seconds)),
        locked_at = null,
        last_error = left(coalesce(p_error, 'retryable'), 120)
    where id = p_job_id;
  elsif p_outcome = 'stale' then
    delete from public.message_preparation_jobs where id = p_job_id;
  elsif p_outcome in ('failed', 'ready') then
    update public.message_preparation_jobs
    set status = p_outcome,
        locked_at = null,
        last_error = case when p_outcome = 'failed'
          then left(coalesce(p_error, 'failed'), 120) else null end
    where id = p_job_id;
    if p_outcome = 'failed' then
      insert into public.message_prepared_packages (
        message_id, chat_id, viewer_id, learning_language,
        primary_known_language, language_revision, source_version,
        status, error_code, resolved_at
      ) values (
        v_job.message_id, v_job.chat_id, v_job.viewer_id,
        v_job.learning_language, v_job.primary_known_language,
        v_job.language_revision, v_job.source_version,
        'failed', left(coalesce(p_error, 'failed'), 120), now()
      )
      on conflict (
        message_id, viewer_id, learning_language, primary_known_language,
        language_revision, source_version
      ) do update set
        status = 'failed',
        error_code = excluded.error_code,
        resolved_at = now();
    end if;
  else
    return false;
  end if;
  return true;
end;
$$;
