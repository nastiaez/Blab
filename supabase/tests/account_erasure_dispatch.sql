-- Disposable CI backend only. Rolled back before pg_net can send any request.
begin;
delete from public.stream_event_inbox;
delete from public.stream_account_erasure;
delete from public.stream_account_send_fences;
delete from vault.secrets where name in ('blab_stream_worker_url','blab_worker_service_role_key');
select vault.create_secret('https://example.invalid/functions/v1/reconcile-stream-events','blab_stream_worker_url');
select vault.create_secret(repeat('x',40),'blab_worker_service_role_key');
do $$
declare n bigint;
begin
 select count(*) into n from net.http_request_queue;
 perform private.request_stream_reconciliation();
 if (select count(*) from net.http_request_queue)<>n then raise exception 'empty queues dispatched'; end if;
 insert into public.stream_account_erasure(user_id) values(gen_random_uuid());
 perform private.request_stream_reconciliation();
 if (select count(*) from net.http_request_queue)<>n+1 then raise exception 'privacy-only erasure queue did not dispatch'; end if;
 delete from public.stream_account_erasure;
 insert into public.stream_account_send_fences(message_id,chat_id,actor_id,blocked_at)
 values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),now());
 perform private.request_stream_reconciliation();
 if (select count(*) from net.http_request_queue)<>n+2 then raise exception 'privacy-only send fence did not dispatch'; end if;
 if has_function_privilege('anon','private.request_stream_reconciliation()','execute') or has_function_privilege('authenticated','private.request_stream_reconciliation()','execute') then raise exception 'worker dispatch exposed'; end if;
end $$;
rollback;
