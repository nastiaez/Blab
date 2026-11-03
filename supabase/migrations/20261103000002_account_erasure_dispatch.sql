-- BLA31: privacy-only queues must wake the existing recovery worker.
-- Preserve its schedule, vault authority, URL checks and least privileges.
-- Immediate asynchronous dispatch; periodic recovery is only the fallback.
create or replace function private.request_stream_reconciliation()
returns void language plpgsql security definer set search_path=pg_catalog as $$
declare v_url text; v_authority text;
begin
  if not exists(select 1 from public.stream_event_inbox where status in ('pending','processing'))
    and not exists(select 1 from public.stream_account_erasure where status in ('pending','processing'))
    and not exists(select 1 from public.stream_account_send_fences where status in ('pending','processing'))
  then return; end if;
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
