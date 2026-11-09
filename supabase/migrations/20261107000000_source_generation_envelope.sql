-- Forward-only metadata preservation. No row writes or historical backfill.
-- US-015: content acceptance is readable structure plus nonempty sentences.
-- Authorization, current source/preferences and lease fencing remain independent.
create or replace function public.normalize_translation_storage_result(p_result jsonb)
returns jsonb language plpgsql immutable set search_path=public as $$
declare r jsonb; f jsonb; envelope jsonb; has_envelope boolean;
begin
 if p_result is null or jsonb_typeof(p_result) is distinct from 'object'
   or jsonb_typeof(p_result->'translation') is distinct from 'string'
   or nullif(btrim(p_result->>'translation'),'') is null
   or jsonb_typeof(p_result->'interfaceText') is distinct from 'string'
   or nullif(btrim(p_result->>'interfaceText'),'') is null then return null; end if;
 r:=p_result || jsonb_build_object(
  'mode',case when p_result->>'mode' in ('translation','correction','none') then p_result->>'mode' else 'translation' end,
  'sourceLang',case when p_result->>'sourceLang' in ('en','nl','fr','de','hi','it','pt','es','ta','tr','uk','da','fi','ko','mr','pl','other') then p_result->>'sourceLang' else 'other' end,
  'explanation',case when jsonb_typeof(p_result->'explanation')='string' then p_result->>'explanation' else null end,
  'confidence',case when p_result->>'confidence' in ('low','medium','high') then p_result->>'confidence' else null end,
  'tokens',case when jsonb_typeof(p_result->'tokens')='array' then p_result->'tokens' else '[]'::jsonb end);
 f:=p_result->'formAlternatives';
 -- Presence, not validity, disables legacy diff. Malformed markers must survive.
 has_envelope := p_result ? 'generationEnvelope'
   or (jsonb_typeof(f) = 'object' and f ? 'blabGenerationEnvelope');
 envelope := case when p_result ? 'generationEnvelope'
   then p_result->'generationEnvelope' else f->'blabGenerationEnvelope' end;
 if jsonb_typeof(envelope) is distinct from 'object' then
   envelope := '{}'::jsonb;
 end if;
 -- Optional malformed form data is omitted, never a reason to reject a sentence.
 if jsonb_typeof(f) is distinct from 'object'
   or not coalesce(f ?& array['before','feminine','masculine','after','subjectName','subjectIsViewer','subjectRole','feminineTokens','masculineTokens'],false)
   or exists(select 1 from unnest(array['before','feminine','masculine','after','subjectName']) k where jsonb_typeof(f->k) is distinct from 'string')
   or jsonb_typeof(f->'subjectIsViewer') is distinct from 'boolean'
   or coalesce(f->>'subjectRole','') not in ('author','recipient')
   or jsonb_typeof(f->'feminineTokens') is distinct from 'array'
   or jsonb_typeof(f->'masculineTokens') is distinct from 'array' then f:=null; end if;
 if coalesce(has_envelope,false) then
   f := coalesce(f,'{}'::jsonb) || jsonb_build_object('blabGenerationEnvelope',envelope);
 end if;
 return r || jsonb_build_object('formAlternatives',f);
end; $$;
revoke all on function public.normalize_translation_storage_result(jsonb) from public,anon,authenticated;
grant execute on function public.normalize_translation_storage_result(jsonb) to service_role;


-- Envelope-only provenance is not a grammatical-form choice. Preserve the
-- historical form-shape checks for every other object, without rewriting rows.
do $$
declare t text; c text; old_check text;
begin
 foreach t in array array['message_translations','message_prepared_packages'] loop
  c := t || '_form_subject_role_check';
  select pg_get_expr(conbin,conrelid) into old_check from pg_constraint
   where conrelid=('public.'||t)::regclass and conname=c;
  if old_check is null then raise exception 'Missing form constraint: %',c; end if;
  execute format('alter table public.%I drop constraint %I',t,c);
  execute format('alter table public.%I add constraint %I check ((%s) or
   (jsonb_typeof(form_alternatives) = ''object''
    and form_alternatives ? ''blabGenerationEnvelope''
    and form_alternatives - ''blabGenerationEnvelope'' = ''{}''::jsonb
    and jsonb_typeof(form_alternatives->''blabGenerationEnvelope'') = ''object''))',t,c,old_check);
 end loop;
end $$;
