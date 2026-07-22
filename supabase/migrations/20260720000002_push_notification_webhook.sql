-- L-17: asynchronously dispatch push outbox rows to the send-push Edge
-- Function. Environment-specific values live in Supabase Vault, not in this
-- migration or the trigger definition.

create extension if not exists pg_net with schema extensions;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.dispatch_push_notification_event()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  v_webhook_secret text;
  v_webhook_url text;
begin
  select decrypted_secret
  into v_webhook_secret
  from vault.decrypted_secrets
  where name = 'blab_push_webhook_secret';

  select decrypted_secret
  into v_webhook_url
  from vault.decrypted_secrets
  where name = 'blab_push_webhook_url';

  if v_webhook_secret is null
      or length(v_webhook_secret) < 24
      or v_webhook_url is null
      or v_webhook_url !~ '^https://[^/]+/functions/v1/send-push$' then
    raise warning 'Blab push webhook is not configured';
    return new;
  end if;

  perform net.http_post(
    url := v_webhook_url,
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', tg_table_name,
      'schema', tg_table_schema,
      'record', to_jsonb(new),
      'old_record', null
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-blab-push-secret', v_webhook_secret
    ),
    timeout_milliseconds := 5000
  );

  return new;
exception
  when others then
    -- Push is best effort. A webhook or Vault failure must never roll back a
    -- persisted message, invite claim, or outbox event.
    raise warning 'Blab push webhook dispatch failed: %', sqlerrm;
    return new;
end;
$$;

revoke all on function private.dispatch_push_notification_event()
  from public, anon, authenticated;

drop trigger if exists send_push_notification_event
  on public.push_notification_events;
create trigger send_push_notification_event
  after insert on public.push_notification_events
  for each row execute function private.dispatch_push_notification_event();

comment on function private.dispatch_push_notification_event() is
  'Queues a best-effort pg_net call using encrypted Vault configuration.';
