-- K01: move semantic review and word-help regeneration to an independent,
-- stronger model and anchor every gloss to the accepted Known Language text.

create or replace function public.complete_message_translation(
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
  if p_cache_contract_version <> 'independent-semantic-review-v10' then
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

create or replace function public.complete_message_translation_job(
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
  if p_cache_contract_version <> 'independent-semantic-review-v10' then
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
  'independent_semantic_review_cache_invalidated'
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

delete from public.message_prepared_packages;
delete from public.message_translations;

alter table public.message_translations
  drop constraint message_translations_cache_contract_version_check,
  add constraint message_translations_cache_contract_version_check
  check (cache_contract_version = 'independent-semantic-review-v10');
