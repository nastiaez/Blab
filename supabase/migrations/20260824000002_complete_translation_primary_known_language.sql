create or replace function public.complete_message_translation(
  p_message_id uuid, p_requester_id uuid, p_target_lang text, p_interface_lang text,
  p_source_hash text, p_translation_text text, p_interface_text text, p_source_lang text,
  p_aid_mode text, p_explanation text, p_confidence text, p_tokens jsonb,
  p_form_alternatives jsonb
) returns boolean
language plpgsql security definer set search_path = public, extensions
as $$
declare v_body text;
begin
  if auth.role() is distinct from 'service_role' then raise insufficient_privilege using message = 'service_role_required'; end if;
  if p_target_lang not in ('nl','en','fr','de','hi','it','pt','es','ta','tr','uk')
    or p_source_lang not in ('nl','en','fr','de','hi','it','pt','es','ta','tr','uk','other')
    or p_interface_lang not in ('en','uk','de','es') or p_aid_mode not in ('translation','correction','none')
    or p_source_hash !~ '^[0-9a-f]{64}$' or btrim(p_translation_text) = ''
    or btrim(p_interface_text) = '' or jsonb_typeof(p_tokens) <> 'array' then return false; end if;
  if p_form_alternatives is not null and (
    p_aid_mode <> 'translation' or jsonb_typeof(p_form_alternatives) <> 'object'
    or not (p_form_alternatives ?& array['before','feminine','masculine','after','subjectName','subjectIsViewer'])
    or jsonb_typeof(p_form_alternatives->'before') <> 'string'
    or jsonb_typeof(p_form_alternatives->'feminine') <> 'string'
    or jsonb_typeof(p_form_alternatives->'masculine') <> 'string'
    or jsonb_typeof(p_form_alternatives->'after') <> 'string'
    or jsonb_typeof(p_form_alternatives->'subjectName') <> 'string'
    or jsonb_typeof(p_form_alternatives->'subjectIsViewer') <> 'boolean'
    or btrim(p_form_alternatives->>'feminine') = ''
    or btrim(p_form_alternatives->>'masculine') = ''
    or p_form_alternatives->>'feminine' = p_form_alternatives->>'masculine'
    or (
      coalesce(p_form_alternatives->>'before','') ||
      coalesce(p_form_alternatives->>'feminine','') ||
      coalesce(p_form_alternatives->>'after','')
    ) <> p_translation_text
  ) then return false; end if;
  select m.body into v_body
  from public.messages m
  join public.chat_members cm on cm.chat_id=m.chat_id
    and cm.user_id=p_requester_id and cm.learning_language=p_target_lang
    and (cm.translation_cutoff_at is null or m.created_at >= cm.translation_cutoff_at)
  join public.profiles p on p.id=p_requester_id
    and coalesce(p.primary_known_language, p.interface_language)=p_interface_lang
  where m.id=p_message_id and m.deleted_at is null and public.is_account_active(p_requester_id);
  if not found or encode(digest(convert_to(btrim(v_body),'UTF8'),'sha256'),'hex') <> p_source_hash then return false; end if;
  if p_interface_lang=p_target_lang and p_interface_text<>p_translation_text then return false; end if;
  if p_source_lang=p_interface_lang and p_source_lang<>p_target_lang and p_interface_text<>btrim(v_body) then return false; end if;
  if p_aid_mode='translation' then
    if p_source_lang=p_target_lang or p_explanation is not null or p_confidence is not null then return false; end if;
  elsif p_aid_mode='correction' then
    if p_source_lang<>p_target_lang or p_translation_text=btrim(v_body) or nullif(btrim(p_explanation),'') is null or p_confidence not in ('low','medium','high') then return false; end if;
  else
    if p_source_lang<>p_target_lang or p_translation_text<>btrim(v_body) or p_explanation is not null or p_confidence is not null then return false; end if;
  end if;
  insert into public.message_translations (message_id,target_lang,interface_lang,aid_mode,translation_text,interface_text,source_lang,explanation,confidence,tokens,source_hash,form_alternatives)
  values (p_message_id,p_target_lang,p_interface_lang,p_aid_mode,p_translation_text,p_interface_text,p_source_lang,p_explanation,p_confidence,p_tokens,p_source_hash,p_form_alternatives)
  on conflict (message_id,target_lang,interface_lang) do update set aid_mode=excluded.aid_mode, translation_text=excluded.translation_text,
    interface_text=excluded.interface_text, source_lang=excluded.source_lang, explanation=excluded.explanation,
    confidence=excluded.confidence, tokens=excluded.tokens, source_hash=excluded.source_hash,
    form_alternatives=excluded.form_alternatives, created_at=now();
  return true;
end;
$$;

revoke all on function public.complete_message_translation(uuid, uuid, text, text, text, text, text, text, text, text, text, jsonb, jsonb) from public;
grant execute on function public.complete_message_translation(uuid, uuid, text, text, text, text, text, text, text, text, text, jsonb, jsonb) to service_role;
