-- Queue state is authoritative: waiting for provider backoff is not a final failure.
-- US-043 / US-044: an authorized viewer can distinguish active delivery
-- preparation from failure without reading jobs or reserving another request.
create or replace function public.message_translation_work_pending(
  p_message_id uuid, p_target_lang text, p_interface_lang text
) returns boolean
language sql stable security definer
set search_path = public, extensions
as $$
  select public.is_account_active(auth.uid()) and exists (
    select 1 from public.message_preparation_jobs j
    join public.messages m on m.id = j.message_id and m.deleted_at is null
    join public.chat_members cm on cm.chat_id = m.chat_id and cm.user_id = auth.uid()
    join public.profiles p on p.id = cm.user_id
    cross join lateral public.resolve_message_learning_era(m.id, cm.user_id) era
    where j.message_id = p_message_id and j.viewer_id = auth.uid()
      and j.primary_known_language = p_interface_lang
      and p.primary_known_language = p_interface_lang
      and p_target_lang in (j.learning_language, j.primary_known_language)
      and j.learning_language = era.learning_language
      and j.language_revision = era.language_revision
      and j.source_version = encode(digest(convert_to(btrim(m.body), 'UTF8'), 'sha256'), 'hex')
      and j.status in ('processing', 'queued')
  );
$$;
revoke all on function public.message_translation_work_pending(uuid,text,text) from public, anon;
grant execute on function public.message_translation_work_pending(uuid,text,text) to authenticated;

-- Avoid dispatching idle workers while both phase lanes are full.
select cron.unschedule(jobid) from cron.job where jobname='blab-message-preparation-recovery';
select cron.schedule('blab-message-preparation-recovery','2 seconds',
  $cron$select private.request_message_preparation_worker()
  where exists(select 1 from public.message_preparation_jobs j
    where (j.status='processing' and j.locked_at<now()-interval '45 seconds')
      or (j.status='queued' and j.available_at<=now() and
        (select count(*) from public.message_preparation_jobs busy
          where busy.status='processing' and busy.phase=j.phase)
          < case j.phase when 'sentence' then 3 else 1 end))$cron$);
