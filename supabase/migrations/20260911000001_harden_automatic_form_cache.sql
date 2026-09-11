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

-- A translated message may originate in the reader's interface language and
-- still need a clear grammar/spelling correction for the main chat line. The
-- previous validators required that lane to equal the authored body exactly,
-- discarding the correction even though the provider contract requested it.
create or replace function public.complete_message_translation(
  p_message_id uuid, p_requester_id uuid, p_target_lang text,
  p_interface_lang text, p_source_hash text, p_translation_text text,
  p_interface_text text, p_source_lang text, p_aid_mode text,
  p_explanation text, p_confidence text, p_tokens jsonb,
  p_form_alternatives jsonb
) returns boolean
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_body text;
  v_mode text;
  v_learning_lang text;
  v_primary_known text;
  v_expected_target text;
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  if p_target_lang not in ('nl','en','fr','de','hi','it','pt','es','ta','tr','uk')
    or p_source_lang not in ('nl','en','fr','de','hi','it','pt','es','ta','tr','uk','other')
    or p_interface_lang not in ('en','uk','de','es')
    or p_aid_mode not in ('translation','correction','none')
    or p_source_hash !~ '^[0-9a-f]{64}$'
    or btrim(p_translation_text) = '' or btrim(p_interface_text) = ''
    or jsonb_typeof(p_tokens) <> 'array' then return false;
  end if;
  if p_form_alternatives is not null and (
    p_aid_mode <> 'translation'
    or jsonb_typeof(p_form_alternatives) <> 'object'
    or not (p_form_alternatives ?& array[
      'before','feminine','masculine','after','subjectName','subjectIsViewer'
    ])
    or jsonb_typeof(p_form_alternatives->'before') <> 'string'
    or jsonb_typeof(p_form_alternatives->'feminine') <> 'string'
    or jsonb_typeof(p_form_alternatives->'masculine') <> 'string'
    or jsonb_typeof(p_form_alternatives->'after') <> 'string'
    or jsonb_typeof(p_form_alternatives->'subjectName') <> 'string'
    or jsonb_typeof(p_form_alternatives->'subjectIsViewer') <> 'boolean'
    or btrim(p_form_alternatives->>'feminine') = ''
    or btrim(p_form_alternatives->>'masculine') = ''
    or p_form_alternatives->>'feminine' = p_form_alternatives->>'masculine'
    or coalesce(p_form_alternatives->>'before','') ||
       coalesce(p_form_alternatives->>'feminine','') ||
       coalesce(p_form_alternatives->>'after','') <> p_translation_text
  ) then return false;
  end if;

  select m.body, cm.mode,
         coalesce(p.primary_known_language, p.interface_language)
    into v_body, v_mode, v_primary_known
  from public.messages m
  join public.chat_members cm
    on cm.chat_id = m.chat_id and cm.user_id = p_requester_id
  join public.profiles p on p.id = p_requester_id
  where m.id = p_message_id
    and m.deleted_at is null
    and public.is_account_active(p_requester_id);
  if not found then return false;
  end if;

  select era.learning_language into v_learning_lang
  from public.resolve_message_learning_era(p_message_id, p_requester_id) era;
  if not found then return false;
  end if;
  v_expected_target := case when v_mode = 'practice'
    then v_learning_lang else v_primary_known end;
  if p_target_lang <> v_expected_target
      or p_interface_lang <> v_primary_known then return false;
  end if;
  if encode(digest(convert_to(btrim(v_body),'UTF8'),'sha256'),'hex')
      <> p_source_hash then return false;
  end if;
  if p_interface_lang = p_target_lang
      and p_interface_text <> p_translation_text then return false;
  end if;
  if p_aid_mode = 'translation' then
    if p_source_lang = p_target_lang
        or p_explanation is not null or p_confidence is not null then
      return false;
    end if;
  elsif p_aid_mode = 'correction' then
    if p_source_lang <> p_target_lang
        or p_translation_text = btrim(v_body)
        or nullif(btrim(p_explanation), '') is null
        or p_confidence not in ('low','medium','high') then return false;
    end if;
  else
    if p_source_lang <> p_target_lang
        or p_translation_text <> btrim(v_body)
        or p_explanation is not null or p_confidence is not null then
      return false;
    end if;
  end if;

  insert into public.message_translations (
    message_id,target_lang,interface_lang,aid_mode,translation_text,
    interface_text,source_lang,explanation,confidence,tokens,source_hash,
    form_alternatives
  ) values (
    p_message_id,p_target_lang,p_interface_lang,p_aid_mode,p_translation_text,
    p_interface_text,p_source_lang,p_explanation,p_confidence,p_tokens,
    p_source_hash,p_form_alternatives
  )
  on conflict (message_id,target_lang,interface_lang) do update set
    aid_mode=excluded.aid_mode,
    translation_text=excluded.translation_text,
    interface_text=excluded.interface_text,
    source_lang=excluded.source_lang,
    explanation=excluded.explanation,
    confidence=excluded.confidence,
    tokens=excluded.tokens,
    source_hash=excluded.source_hash,
    form_alternatives=excluded.form_alternatives,
    created_at=now();
  return true;
end;
$$;

create or replace function public.complete_message_translation_job(
  p_job_id uuid, p_translation_text text, p_interface_text text,
  p_source_lang text, p_aid_mode text, p_explanation text,
  p_confidence text, p_tokens jsonb, p_form_alternatives jsonb
) returns boolean
language plpgsql security definer set search_path = public, extensions
as $$
declare
  v_job public.message_preparation_jobs%rowtype;
  v_message public.messages%rowtype;
  v_era record;
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  select * into v_job
  from public.message_preparation_jobs
  where id = p_job_id and status = 'processing'
  for update;
  if not found then return false;
  end if;
  select * into v_message
  from public.messages
  where id = v_job.message_id and deleted_at is null;
  if not found
      or encode(digest(convert_to(btrim(v_message.body), 'UTF8'), 'sha256'), 'hex')
        <> v_job.source_version then return false;
  end if;
  select * into v_era
  from public.resolve_message_learning_era(v_job.message_id, v_job.viewer_id);
  if not found
      or v_era.learning_language <> v_job.learning_language
      or v_era.language_revision <> v_job.language_revision then return false;
  end if;
  if v_job.learning_language not in ('nl','en','fr','de','hi','it','pt','es','ta','tr','uk')
    or p_source_lang not in ('nl','en','fr','de','hi','it','pt','es','ta','tr','uk','other')
    or v_job.primary_known_language not in ('en','uk','de','es')
    or p_aid_mode not in ('translation','correction','none')
    or btrim(p_translation_text) = '' or btrim(p_interface_text) = ''
    or jsonb_typeof(p_tokens) <> 'array' then return false;
  end if;
  if p_form_alternatives is not null and (
    p_aid_mode <> 'translation'
    or jsonb_typeof(p_form_alternatives) <> 'object'
    or not (p_form_alternatives ?& array[
      'before','feminine','masculine','after','subjectName','subjectIsViewer'
    ])
    or btrim(p_form_alternatives->>'feminine') = ''
    or btrim(p_form_alternatives->>'masculine') = ''
    or p_form_alternatives->>'feminine' = p_form_alternatives->>'masculine'
    or coalesce(p_form_alternatives->>'before','') ||
       coalesce(p_form_alternatives->>'feminine','') ||
       coalesce(p_form_alternatives->>'after','') <> p_translation_text
  ) then return false;
  end if;
  if v_job.primary_known_language = v_job.learning_language
      and p_interface_text <> p_translation_text then return false;
  end if;
  if p_aid_mode = 'translation' then
    if p_source_lang = v_job.learning_language
        or p_explanation is not null or p_confidence is not null then
      return false;
    end if;
  elsif p_aid_mode = 'correction' then
    if p_source_lang <> v_job.learning_language
        or p_translation_text = btrim(v_message.body)
        or nullif(btrim(p_explanation), '') is null
        or p_confidence not in ('low','medium','high') then return false;
    end if;
  else
    if p_source_lang <> v_job.learning_language
        or p_translation_text <> btrim(v_message.body)
        or p_explanation is not null or p_confidence is not null then
      return false;
    end if;
  end if;

  insert into public.message_translations (
    message_id,target_lang,interface_lang,aid_mode,translation_text,
    interface_text,source_lang,explanation,confidence,tokens,source_hash,
    form_alternatives
  ) values (
    v_job.message_id,v_job.learning_language,v_job.primary_known_language,
    p_aid_mode,p_translation_text,p_interface_text,p_source_lang,p_explanation,
    p_confidence,p_tokens,v_job.source_version,p_form_alternatives
  )
  on conflict (message_id,target_lang,interface_lang) do update set
    aid_mode=excluded.aid_mode,
    translation_text=excluded.translation_text,
    interface_text=excluded.interface_text,
    source_lang=excluded.source_lang,
    explanation=excluded.explanation,
    confidence=excluded.confidence,
    tokens=excluded.tokens,
    source_hash=excluded.source_hash,
    form_alternatives=excluded.form_alternatives,
    created_at=now();

  insert into public.message_prepared_packages (
    message_id,chat_id,viewer_id,learning_language,primary_known_language,
    language_revision,source_version,status,translation_text,interface_text,
    source_lang,aid_mode,explanation,confidence,tokens,form_alternatives,
    error_code,resolved_at
  ) values (
    v_job.message_id,v_job.chat_id,v_job.viewer_id,v_job.learning_language,
    v_job.primary_known_language,v_job.language_revision,v_job.source_version,
    'ready',p_translation_text,p_interface_text,p_source_lang,p_aid_mode,
    p_explanation,p_confidence,p_tokens,p_form_alternatives,null,now()
  )
  on conflict (
    message_id,viewer_id,learning_language,primary_known_language,
    language_revision,source_version
  ) do update set
    status='ready',
    translation_text=excluded.translation_text,
    interface_text=excluded.interface_text,
    source_lang=excluded.source_lang,
    aid_mode=excluded.aid_mode,
    explanation=excluded.explanation,
    confidence=excluded.confidence,
    tokens=excluded.tokens,
    form_alternatives=excluded.form_alternatives,
    error_code=null,
    resolved_at=now();
  update public.message_preparation_jobs
  set status='ready', locked_at=null, last_error=null
  where id=v_job.id;
  return true;
end;
$$;

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
