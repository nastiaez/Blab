-- Immediate asynchronous dispatch; periodic recovery is only the fallback.
create or replace function private.request_stream_reconciliation()
returns void language plpgsql security definer set search_path=pg_catalog as $$
declare v_url text; v_authority text;
begin
  if not exists(select 1 from public.stream_event_inbox where status in ('pending','processing')) then return; end if;
  select decrypted_secret into v_url from vault.decrypted_secrets where name='blab_stream_worker_url';
  select decrypted_secret into v_authority from vault.decrypted_secrets where name='blab_worker_service_role_key';
  if v_url is null or v_url !~ '^https?://[^/]+/functions/v1/reconcile-stream-events$'
    or v_authority is null or length(v_authority)<24 then return; end if;
  perform net.http_post(url:=v_url,body:='{}'::jsonb,
    headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||v_authority),
    timeout_milliseconds:=15000);
exception when others then
  -- Pending rows remain durable for recovery; never expose credential values.
  raise warning 'Stream reconciliation dispatch unavailable';
end; $$;
revoke all on function private.request_stream_reconciliation() from public,anon,authenticated;
create or replace function private.dispatch_stream_reconciliation()
returns trigger language plpgsql security definer set search_path=pg_catalog as $$
begin
  perform private.request_stream_reconciliation();
  return null;
end; $$;
revoke all on function private.dispatch_stream_reconciliation() from public,anon,authenticated;
create trigger dispatch_stream_reconciliation after insert on public.stream_event_inbox
  for each row execute function private.dispatch_stream_reconciliation();
do $$
declare v_job bigint;
begin
  select jobid into v_job from cron.job where jobname='blab-stream-event-recovery';
  if v_job is not null then perform cron.unschedule(v_job); end if;
  perform cron.schedule('blab-stream-event-recovery','* * * * *','select private.request_stream_reconciliation();');
end; $$;
