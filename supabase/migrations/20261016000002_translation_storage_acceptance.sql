-- US-015: content acceptance is readable structure plus nonempty sentences.
-- Authorization, current source/preferences and lease fencing remain independent.
create or replace function public.normalize_translation_storage_result(p_result jsonb)
returns jsonb language plpgsql immutable set search_path=public as $$
declare r jsonb; f jsonb;
begin
 if p_result is null or jsonb_typeof(p_result) is distinct from 'object'
   or jsonb_typeof(p_result->'translation') is distinct from 'string'
   or nullif(btrim(p_result->>'translation'),'') is null
   or jsonb_typeof(p_result->'interfaceText') is distinct from 'string'
   or nullif(btrim(p_result->>'interfaceText'),'') is null then return null; end if;
 r:=p_result || jsonb_build_object(
  'mode',case when p_result->>'mode' in ('translation','correction','none') then p_result->>'mode' else 'translation' end,
  'sourceLang',case when p_result->>'sourceLang' in ('en','nl','fr','de','hi','it','pt','es','ta','tr','uk','other') then p_result->>'sourceLang' else 'other' end,
  'explanation',case when jsonb_typeof(p_result->'explanation')='string' then p_result->>'explanation' else null end,
  'confidence',case when p_result->>'confidence' in ('low','medium','high') then p_result->>'confidence' else null end,
  'tokens',case when jsonb_typeof(p_result->'tokens')='array' then p_result->'tokens' else '[]'::jsonb end);
 f:=p_result->'formAlternatives';
 -- Optional malformed form data is omitted, never a reason to reject a sentence.
 if jsonb_typeof(f) is distinct from 'object'
   or not coalesce(f ?& array['before','feminine','masculine','after','subjectName','subjectIsViewer','subjectRole','feminineTokens','masculineTokens'],false)
   or exists(select 1 from unnest(array['before','feminine','masculine','after','subjectName']) k where jsonb_typeof(f->k) is distinct from 'string')
   or jsonb_typeof(f->'subjectIsViewer') is distinct from 'boolean'
   or coalesce(f->>'subjectRole','') not in ('author','recipient')
   or jsonb_typeof(f->'feminineTokens') is distinct from 'array'
   or jsonb_typeof(f->'masculineTokens') is distinct from 'array' then f:=null; end if;
 return r || jsonb_build_object('formAlternatives',f);
end; $$;
revoke all on function public.normalize_translation_storage_result(jsonb) from public,anon,authenticated;
grant execute on function public.normalize_translation_storage_result(jsonb) to service_role;

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
  v_result jsonb;
  v_body text;
  v_mode text;
  v_learning_lang text;
  v_primary_known text;
  v_expected_target text;
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  v_result:=public.normalize_translation_storage_result(jsonb_build_object(
    'translation',p_translation_text,'interfaceText',p_interface_text,
    'mode',p_aid_mode,'sourceLang',p_source_lang,'explanation',p_explanation,
    'confidence',p_confidence,'tokens',p_tokens,'formAlternatives',p_form_alternatives));
  if v_result is null then return false; end if;
  p_aid_mode:=v_result->>'mode'; p_source_lang:=v_result->>'sourceLang';
  p_explanation:=v_result->>'explanation'; p_confidence:=v_result->>'confidence';
  p_tokens:=v_result->'tokens'; p_form_alternatives:=nullif(v_result->'formAlternatives','null'::jsonb);

  if p_target_lang is null or p_interface_lang is null or p_source_hash is null then return false; end if;
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
  v_result jsonb;
  v_job public.message_preparation_jobs%rowtype;
  v_message public.messages%rowtype;
  v_era record;
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;
  v_result:=public.normalize_translation_storage_result(jsonb_build_object(
    'translation',p_translation_text,'interfaceText',p_interface_text,
    'mode',p_aid_mode,'sourceLang',p_source_lang,'explanation',p_explanation,
    'confidence',p_confidence,'tokens',p_tokens,'formAlternatives',p_form_alternatives));
  if v_result is null then return false; end if;
  p_aid_mode:=v_result->>'mode'; p_source_lang:=v_result->>'sourceLang';
  p_explanation:=v_result->>'explanation'; p_confidence:=v_result->>'confidence';
  p_tokens:=v_result->'tokens'; p_form_alternatives:=nullif(v_result->'formAlternatives','null'::jsonb);

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

create or replace function public.publish_message_readable_variant(
 p_message_id uuid,p_viewer_id uuid,p_target_lang text,p_interface_lang text,
 p_language_revision integer,p_source_hash text,p_result jsonb,
 p_cache_contract_version text
) returns boolean language plpgsql security definer set search_path=public,extensions as $$
declare v_chat uuid; v_primary text; v_era record; v_body text;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 if p_cache_contract_version is distinct from 'minimal-source-anchor-v11' then return false; end if;
 select m.chat_id,m.body,coalesce(p.primary_known_language,p.interface_language) into v_chat,v_body,v_primary
 from messages m join chat_members cm on cm.chat_id=m.chat_id and cm.user_id=p_viewer_id
 join profiles p on p.id=p_viewer_id
 where m.id=p_message_id and m.deleted_at is null and is_account_active(p_viewer_id)
 for share of m,cm,p;
 if not found then return false; end if;
 select * into v_era from resolve_message_learning_era(p_message_id,p_viewer_id);
 if not found or p_language_revision is null or v_era.language_revision is distinct from p_language_revision
   or p_target_lang is null or p_target_lang not in (v_era.learning_language,v_primary)
   or p_interface_lang is distinct from v_primary
   or encode(digest(convert_to(btrim(v_body),'UTF8'),'sha256'),'hex') is distinct from p_source_hash then return false; end if;
 p_result:=public.normalize_translation_storage_result(p_result);
 if p_result is null then return false; end if;
 insert into message_readable_variants(message_id,viewer_id,chat_id,target_lang,learning_language,interface_lang,language_revision,source_hash,result)
 values(p_message_id,p_viewer_id,v_chat,p_target_lang,v_era.learning_language,p_interface_lang,p_language_revision,p_source_hash,
  jsonb_build_object('mode',p_result->'mode','sourceLang',p_result->'sourceLang',
   'translation',p_result->'translation','interfaceText',p_result->'interfaceText',
   'explanation',p_result->'explanation','confidence',p_result->'confidence','formAlternatives',p_result->'formAlternatives'))
 on conflict(message_id,viewer_id,target_lang,interface_lang) do update set
  learning_language=excluded.learning_language,language_revision=excluded.language_revision,source_hash=excluded.source_hash,result=excluded.result,created_at=now();
 return true;
end; $$;
revoke all on function public.publish_message_readable_variant(uuid,uuid,text,text,integer,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.publish_message_readable_variant(uuid,uuid,text,text,integer,text,jsonb,text) to service_role;

