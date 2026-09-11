-- US-042 / FR-34: shared grammatical-form alternatives identify the affected
-- participant by message role, never by a viewer-relative boolean alone.
-- Deployment dependency: Task 3 must populate feminineTokens and
-- masculineTokens before this migration and its function changes ship.

-- Hold an access-exclusive cache-table lock for the rest of this migration and
-- make every new shared translation identify the contract that produced it.
-- Legacy RPCs omit the session-local contract and therefore fail the final
-- NOT NULL gate before they can create any derived prepared package.
alter table public.message_translations
  add column cache_contract_version text
  default nullif(current_setting('blab.cache_contract_version', true), '');

-- New edge code calls the versioned overload. It sets the transaction-local
-- contract used by the cache-column defaults, then delegates to the existing
-- validated completion body. The unversioned overload is retained only as the
-- internal implementation and is no longer callable by the service role.
create function public.complete_message_translation(
  p_message_id uuid, p_requester_id uuid, p_target_lang text,
  p_interface_lang text, p_source_hash text, p_translation_text text,
  p_interface_text text, p_source_lang text, p_aid_mode text,
  p_explanation text, p_confidence text, p_tokens jsonb,
  p_form_alternatives jsonb, p_cache_contract_version text
) returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  if p_cache_contract_version <> 'automatic-forms-v2' then
    return false;
  end if;
  perform set_config(
    'blab.cache_contract_version',
    p_cache_contract_version,
    true
  );
  return public.complete_message_translation(
    p_message_id, p_requester_id, p_target_lang, p_interface_lang,
    p_source_hash, p_translation_text, p_interface_text, p_source_lang,
    p_aid_mode, p_explanation, p_confidence, p_tokens, p_form_alternatives
  );
end;
$$;

create function public.complete_message_translation_job(
  p_job_id uuid, p_translation_text text, p_interface_text text,
  p_source_lang text, p_aid_mode text, p_explanation text,
  p_confidence text, p_tokens jsonb, p_form_alternatives jsonb,
  p_cache_contract_version text
) returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  if p_cache_contract_version <> 'automatic-forms-v2' then
    return false;
  end if;
  perform set_config(
    'blab.cache_contract_version',
    p_cache_contract_version,
    true
  );
  return public.complete_message_translation_job(
    p_job_id, p_translation_text, p_interface_text, p_source_lang,
    p_aid_mode, p_explanation, p_confidence, p_tokens, p_form_alternatives
  );
end;
$$;

revoke all on function public.complete_message_translation(
  uuid, uuid, text, text, text, text, text, text, text, text, text,
  jsonb, jsonb
) from public, anon, authenticated, service_role;
revoke all on function public.complete_message_translation_job(
  uuid, text, text, text, text, text, text, jsonb, jsonb
) from public, anon, authenticated, service_role;
revoke all on function public.complete_message_translation(
  uuid, uuid, text, text, text, text, text, text, text, text, text,
  jsonb, jsonb, text
) from public, anon, authenticated;
grant execute on function public.complete_message_translation(
  uuid, uuid, text, text, text, text, text, text, text, text, text,
  jsonb, jsonb, text
) to service_role;
revoke all on function public.complete_message_translation_job(
  uuid, text, text, text, text, text, text, jsonb, jsonb, text
) from public, anon, authenticated;
grant execute on function public.complete_message_translation_job(
  uuid, text, text, text, text, text, text, jsonb, jsonb, text
) to service_role;

-- Prepared packages can outlive their translation-cache source row. Replace
-- completed and in-flight jobs instead of reusing their IDs. A legacy worker
-- holding an old ID must fail completion even if the replacement is claimed
-- before that old worker returns (the otherwise possible ABA race). Do this
-- before purging caches so the row lock also makes every old completion settle
-- before the final delete statements run.
with invalidated_jobs as (
  delete from public.message_preparation_jobs
  where status in ('processing', 'ready')
  returning message_id, chat_id, viewer_id, learning_language,
    primary_known_language, language_revision, source_version
)
insert into public.message_preparation_jobs (
  message_id, chat_id, viewer_id, learning_language,
  primary_known_language, language_revision, source_version, last_error
)
select
  message_id, chat_id, viewer_id, learning_language,
  primary_known_language, language_revision, source_version,
  'automatic_form_cache_invalidated'
from invalidated_jobs
on conflict (
  message_id, viewer_id, learning_language, primary_known_language,
  language_revision, source_version
) do update set
  id = excluded.id,
  status = 'queued',
  attempts = 0,
  available_at = now(),
  locked_at = null,
  last_error = excluded.last_error;

-- The previous worker could bake a viewer's saved form into translation text
-- and then return null form_alternatives because no choice remained. That
-- makes shape-based filtering insufficient: every legacy cache variant is
-- potentially preference-dependent and must regenerate under the safe prompt.
-- Purging after job replacement also removes output committed by an old worker
-- while the replacement statement waited for that worker's job-row lock.
delete from public.message_prepared_packages;
delete from public.message_translations;

alter table public.message_translations
  alter column cache_contract_version set not null,
  add constraint message_translations_cache_contract_version_check
  check (cache_contract_version = 'automatic-forms-v2'),
  add constraint message_translations_form_subject_role_check
  check (
    form_alternatives is null
    or (
      jsonb_typeof(form_alternatives) = 'object'
      and coalesce(
        jsonb_typeof(form_alternatives -> 'subjectRole') = 'string',
        false
      )
      and coalesce(
        form_alternatives ->> 'subjectRole' in ('author', 'recipient'),
        false
      )
      and coalesce(
        jsonb_typeof(form_alternatives -> 'feminineTokens') = 'array',
        false
      )
      and coalesce(
        jsonb_typeof(form_alternatives -> 'masculineTokens') = 'array',
        false
      )
    )
  );

alter table public.message_prepared_packages
  add constraint message_prepared_packages_form_subject_role_check
  check (
    form_alternatives is null
    or (
      jsonb_typeof(form_alternatives) = 'object'
      and coalesce(
        jsonb_typeof(form_alternatives -> 'subjectRole') = 'string',
        false
      )
      and coalesce(
        form_alternatives ->> 'subjectRole' in ('author', 'recipient'),
        false
      )
      and coalesce(
        jsonb_typeof(form_alternatives -> 'feminineTokens') = 'array',
        false
      )
      and coalesce(
        jsonb_typeof(form_alternatives -> 'masculineTokens') = 'array',
        false
      )
    )
  );
