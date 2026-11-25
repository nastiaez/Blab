-- Install before deploying the compatible worker; activation is separate.
CREATE OR REPLACE FUNCTION private.dispatch_translation(p_message_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
declare
  v_url text;
  v_service_key text;
begin
  select decrypted_secret into v_url
  from vault.decrypted_secrets
  where name = 'blab_translation_worker_url';
  select decrypted_secret into v_service_key
  from vault.decrypted_secrets
  where name = 'blab_worker_service_role_key';
  if v_url is null
      or v_url !~ '^https?://[^/]+/functions/v1/prepare-message-jobs$'
      or v_service_key is null
      or length(v_service_key) < 24 then
    raise warning 'Blab translation worker is not configured';
    return;
  end if;
  perform net.http_post(
    url := v_url,
    body := jsonb_build_object('messageId', p_message_id),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_key
    ),
    timeout_milliseconds := 5000
  );
exception when others then
  raise warning 'Blab translation worker dispatch failed: %', sqlerrm;
end;
$function$;
revoke all on function private.dispatch_translation(uuid) from public, anon, authenticated;

create function public.claim_translation_for_message(p_message_id uuid)
returns setof public.message_preparation_jobs
language plpgsql security definer set search_path=pg_catalog as $$
begin
  if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
  if not pg_try_advisory_xact_lock(hashtext('blab_message_preparation_claim')) then return; end if;

  update public.message_preparation_jobs
  set status=case when attempts>=4 then 'failed' else 'queued' end,
      locked_at=null, lease_token=null, available_at=clock_timestamp(), last_error='lease_expired'
  where message_id=p_message_id and status='processing'
    and locked_at < clock_timestamp()-interval '45 seconds';

  if exists (select from public.message_preparation_jobs where message_id=p_message_id and status='processing')
     or (select count(distinct message_id) from public.message_preparation_jobs where status='processing') >= 4
  then return; end if;

  return query update public.message_preparation_jobs
  set status='processing', locked_at=clock_timestamp(), lease_token=gen_random_uuid(), attempts=attempts+1
  where message_id=p_message_id and status='queued' and available_at<=clock_timestamp()
  returning *;
end $$;
revoke all on function public.claim_translation_for_message(uuid) from public,anon,authenticated;
grant execute on function public.claim_translation_for_message(uuid) to service_role;

-- Called on a state change or a missed deadline. No active tasks means no timer.
create function private.translation_deadline(mid uuid, wake boolean)
returns void language plpgsql security definer set search_path=pg_catalog as $$
declare
  timer_name text := 'blab-tr-' || mid::text;
  next_due timestamptz;
  current_timer cron.job%rowtype;
begin
  perform pg_advisory_xact_lock(hashtextextended(timer_name,0));
  select min(case when status='processing' then locked_at+interval '45 seconds' else available_at end)
    into next_due from public.message_preparation_jobs
    where message_id=mid and status in ('queued','processing');
  select * into current_timer from cron.job where jobname=timer_name and username=current_user;
  if next_due is null then
    if current_timer.jobid is not null then perform cron.unschedule(current_timer.jobid); end if;
    return;
  end if;
  if wake and next_due<=clock_timestamp() then perform private.dispatch_translation(mid); end if;
  -- Only unfinished messages have a timer. A missed minute during downtime
  -- must not defer recovery until the next day or year.
  if current_timer.jobid is null then
    perform cron.schedule(timer_name,'* * * * *',
      format('select private.translation_deadline(%L::uuid,true)',mid));
  end if;
end $$;
revoke all on function private.translation_deadline(uuid,boolean) from public,anon,authenticated;

create function private.translation_job_changed() returns trigger
language plpgsql security definer set search_path=pg_catalog as $$
declare
  mid uuid;
begin
  if tg_op='DELETE' then
    for mid in select distinct message_id from removed_jobs order by message_id loop
      perform private.translation_deadline(mid,false);
    end loop;
  else
    for mid in select distinct message_id from changed_jobs order by message_id loop
      perform private.translation_deadline(mid,exists(
        select from changed_jobs where message_id=mid and status='queued'));
    end loop;
  end if;
  return null;
end $$;
revoke all on function private.translation_job_changed() from public,anon,authenticated;
