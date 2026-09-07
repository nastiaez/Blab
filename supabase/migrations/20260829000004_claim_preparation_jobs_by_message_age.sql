-- `now()` is transaction-stable, so every job from one multi-message insert
-- can share created_at. Order by the persisted message timestamp first.
create or replace function public.claim_message_preparation_jobs_for_worker(
  p_limit integer default 10
) returns setof public.message_preparation_jobs
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  update public.message_preparation_jobs
  set status = 'queued', locked_at = null, available_at = now(),
      last_error = 'lease_expired'
  where status = 'processing'
    and locked_at < now() - interval '5 minutes';
  return query
  with picked as (
    select j.id
    from public.message_preparation_jobs j
    join public.messages m on m.id = j.message_id
    where j.status = 'queued' and j.available_at <= now()
    order by m.created_at, m.id, j.created_at, j.id
    limit greatest(1, least(coalesce(p_limit, 10), 20))
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
