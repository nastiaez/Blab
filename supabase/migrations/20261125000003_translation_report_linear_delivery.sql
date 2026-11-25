-- BLA-61: durable delivery for new reports only. No historical backfill.
create table private.translation_report_linear_outbox (
  report_id uuid primary key references public.translation_reports(id) on delete cascade,
  available_at timestamptz not null default now(),
  attempts integer not null default 0,
  delivered_at timestamptz,
  linear_identifier text
);
create index translation_report_linear_ready
  on private.translation_report_linear_outbox (available_at) where delivered_at is null;
alter table private.translation_report_linear_outbox enable row level security;
revoke all on private.translation_report_linear_outbox from public, anon, authenticated, service_role;

create function private.enqueue_translation_report_linear()
returns trigger language plpgsql security definer set search_path = pg_catalog as $$
begin
  insert into private.translation_report_linear_outbox (report_id) values (new.id);
  return new;
end;
$$;
revoke all on function private.enqueue_translation_report_linear() from public, anon, authenticated, service_role;
create trigger enqueue_translation_report_linear after insert on public.translation_reports
  for each row when (new.environment = 'production')
  execute function private.enqueue_translation_report_linear();

create function public.claim_translation_report_linear()
returns table (report_id uuid, reason text)
language sql security definer set search_path = pg_catalog as $$
  with ready as (
    select q.report_id, r.reason
    from private.translation_report_linear_outbox q
    join public.translation_reports r on r.id = q.report_id
    where q.delivered_at is null and q.available_at <= now()
      and r.environment = 'production'
    order by q.available_at, q.report_id
    limit 8
    for update of q skip locked
  )
  update private.translation_report_linear_outbox q
  set available_at = now() + make_interval(mins => 1 << least(q.attempts + 1, 6)),
      attempts = q.attempts + 1
  from ready
  where q.report_id = ready.report_id
  returning q.report_id, ready.reason;
$$;
revoke all on function public.claim_translation_report_linear() from public, anon, authenticated;
grant execute on function public.claim_translation_report_linear() to service_role;

create function public.finish_translation_report_linear(p_report_id uuid, p_identifier text)
returns void language sql security definer set search_path = pg_catalog as $$
  update private.translation_report_linear_outbox
  set delivered_at = now(), linear_identifier = p_identifier
  where report_id = p_report_id and delivered_at is null
    and p_identifier ~ '^[A-Z][A-Z0-9]*-[0-9]+$';
$$;
revoke all on function public.finish_translation_report_linear(uuid,text) from public, anon, authenticated;
grant execute on function public.finish_translation_report_linear(uuid,text) to service_role;

create function private.request_translation_report_linear()
returns void language plpgsql security definer set search_path = pg_catalog as $$
declare
  worker_url text;
  authority text;
begin
  select decrypted_secret into worker_url from vault.decrypted_secrets
    where name = 'blab_translation_report_linear_worker_url';
  select decrypted_secret into authority from vault.decrypted_secrets
    where name = 'blab_worker_service_role_key';
  if worker_url is distinct from 'https://lwsscssuktjlmiqryfnq.supabase.co/functions/v1/deliver-translation-reports'
    or authority is null or length(authority) < 24 then return; end if;
  if not exists (
    select 1 from private.translation_report_linear_outbox
    where delivered_at is null and available_at <= now()
  ) then return; end if;
  perform net.http_post(url := worker_url, body := '{}'::jsonb,
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ' || authority),
    timeout_milliseconds := 25000);
end;
$$;
revoke all on function private.request_translation_report_linear() from public, anon, authenticated, service_role;
select cron.schedule('blab-translation-report-linear', '* * * * *',
  'select private.request_translation_report_linear();');
