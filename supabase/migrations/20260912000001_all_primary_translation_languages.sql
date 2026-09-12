-- A member's primary known language controls translated message output, not
-- app chrome. Accept every supported Blab language in that output lane.
alter table public.message_translations
  drop constraint message_translations_interface_lang_check,
  add constraint message_translations_interface_lang_check
    check (interface_lang in (
      'nl','en','fr','de','hi','it','pt','es','ta','tr','uk'
    ));

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
    or p_interface_lang not in ('nl','en','fr','de','hi','it','pt','es','ta','tr','uk')
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
    or v_job.primary_known_language not in ('nl','en','fr','de','hi','it','pt','es','ta','tr','uk')
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
