-- Mark the durable delivery job complete whenever the existing, server-owned
-- translation cache receives a matching result. This keeps the queue
-- observable and idempotent without allowing clients to mutate it directly.
create or replace function public.mark_message_preparation_job_ready()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  update public.message_preparation_jobs
  set status = 'ready',
      locked_at = null,
      last_error = null
  where message_id = new.message_id
    and learning_language = new.target_lang
    and primary_known_language = new.interface_lang
    and source_version = new.source_hash
    and status in ('queued', 'processing');
  return new;
end;
$$;

revoke all on function public.mark_message_preparation_job_ready()
  from public, anon, authenticated;
drop trigger if exists mark_message_preparation_job_ready
  on public.message_translations;
create trigger mark_message_preparation_job_ready
  after insert or update on public.message_translations
  for each row execute function public.mark_message_preparation_job_ready();
