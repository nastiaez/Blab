-- Run only after the message-aware worker has passed a hosted invocation.
begin;
lock table public.message_preparation_jobs in share row exclusive mode;
drop trigger dispatch_message_preparation_jobs on public.message_preparation_jobs;
create trigger dispatch_message_preparation_jobs after insert on public.message_preparation_jobs
referencing new table as changed_jobs for each statement execute function private.translation_job_changed();
create trigger update_message_preparation_deadlines after update on public.message_preparation_jobs
referencing new table as changed_jobs for each statement execute function private.translation_job_changed();
create trigger clear_message_preparation_deadlines after delete on public.message_preparation_jobs
referencing old table as removed_jobs for each statement execute function private.translation_job_changed();
select private.translation_deadline(message_id,true)
from (select distinct message_id from public.message_preparation_jobs where status in ('processing','queued')) pending;
select cron.unschedule(jobid) from cron.job where jobname='blab-message-preparation-recovery';
commit;
