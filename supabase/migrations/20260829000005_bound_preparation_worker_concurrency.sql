-- Multiple delivery triggers may fire together. Serialize claims and keep at
-- most four provider jobs in flight across all worker invocations.
create or replace function public.claim_message_preparation_jobs_for_worker(
  p_limit integer default 10
) returns setof public.message_preparation_jobs
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_capacity integer;
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  if not pg_try_advisory_xact_lock(hashtext('blab_message_preparation_claim')) then
    return;
  end if;
  update public.message_preparation_jobs
  set status = 'queued', locked_at = null, available_at = now(),
      last_error = 'lease_expired'
  where status = 'processing'
    and locked_at < now() - interval '5 minutes';
  select greatest(0, 4 - count(*))::integer into v_capacity
  from public.message_preparation_jobs
  where status = 'processing';
  if v_capacity = 0 then return; end if;
  return query
  with picked as (
    select j.id
    from public.message_preparation_jobs j
    join public.messages m on m.id = j.message_id
    where j.status = 'queued' and j.available_at <= now()
    order by m.created_at, m.id, j.created_at, j.id
    limit least(
      v_capacity,
      greatest(1, least(coalesce(p_limit, 10), 20))
    )
    for update of j skip locked
  )
  update public.message_preparation_jobs j
  set status = 'processing', locked_at = now(), attempts = j.attempts + 1
  from picked
  where j.id = picked.id
  returning j.*;
end;
$$;

revoke all on function public.claim_message_preparation_jobs_for_worker(integer)
  from public, anon, authenticated;
grant execute on function public.claim_message_preparation_jobs_for_worker(integer)
  to service_role;
