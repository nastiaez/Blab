-- Give the translation provider a private, weak source-language hint for the
-- current message author. It is used only when a short utterance is genuinely
-- ambiguous after considering the authored text and same-sender context.

create or replace function public.request_message_translation_job(
  p_job_id uuid
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_job public.message_preparation_jobs%rowtype;
  v_message public.messages%rowtype;
  v_era record;
  v_cached public.message_translations%rowtype;
  v_viewer_name text;
  v_viewer_form text;
  v_partner_name text;
  v_partner_form text;
  v_tone text;
  v_author_primary_known_language text;
  v_context jsonb := '[]'::jsonb;
  v_form_context jsonb;
begin
  if auth.role() is distinct from 'service_role' then
    raise insufficient_privilege using message = 'service_role_required';
  end if;

  select * into v_job
  from public.message_preparation_jobs
  where id = p_job_id and status = 'processing'
  for update;
  if not found then
    return jsonb_build_object('status', 'stale');
  end if;

  select * into v_message
  from public.messages
  where id = v_job.message_id and deleted_at is null;
  if not found
      or encode(digest(convert_to(btrim(v_message.body), 'UTF8'), 'sha256'), 'hex')
        <> v_job.source_version then
    return jsonb_build_object('status', 'stale');
  end if;

  select * into v_era
  from public.resolve_message_learning_era(v_job.message_id, v_job.viewer_id);
  if not found
      or v_era.learning_language <> v_job.learning_language
      or v_era.language_revision <> v_job.language_revision then
    return jsonb_build_object('status', 'stale');
  end if;

  select p.display_name, p.grammatical_form,
         cm.partner_grammatical_form, cm.conversation_tone
    into v_viewer_name, v_viewer_form, v_partner_form, v_tone
  from public.chat_members cm
  join public.profiles p on p.id = cm.user_id
  where cm.chat_id = v_job.chat_id and cm.user_id = v_job.viewer_id;
  if not found then
    return jsonb_build_object('status', 'stale');
  end if;

  select p.display_name, coalesce(p.grammatical_form, v_partner_form)
    into v_partner_name, v_partner_form
  from public.chat_members cm
  join public.profiles p on p.id = cm.user_id
  where cm.chat_id = v_job.chat_id and cm.user_id <> v_job.viewer_id
  limit 1;

  select p.primary_known_language
    into v_author_primary_known_language
  from public.profiles p
  where p.id = v_message.sender_id;

  v_form_context := jsonb_build_object(
    'viewerName', coalesce(v_viewer_name, 'you'),
    'partnerName', coalesce(v_partner_name, 'your chat partner'),
    'messageAuthor', case when v_message.sender_id = v_job.viewer_id
      then 'viewer' else 'partner' end,
    'viewerForm', case when v_viewer_form in ('feminine', 'masculine')
      then v_viewer_form else null end,
    'partnerForm', case when v_partner_form in ('feminine', 'masculine')
      then v_partner_form else null end,
    'tone', case when v_tone = 'respectful' then 'respectful' else 'informal' end,
    'authorPrimaryKnownLanguage', case
      when v_author_primary_known_language in
        ('en','nl','fr','de','hi','it','pt','es','ta','tr','uk')
      then v_author_primary_known_language
      else null
    end
  );

  select * into v_cached
  from public.message_translations mt
  where mt.message_id = v_job.message_id
    and mt.target_lang = v_job.learning_language
    and mt.interface_lang = v_job.primary_known_language;
  if found then
    insert into public.message_prepared_packages (
      message_id, chat_id, viewer_id, learning_language,
      primary_known_language, language_revision, source_version, status,
      translation_text, interface_text, source_lang, aid_mode, explanation,
      confidence, tokens, form_alternatives, error_code, resolved_at
    ) values (
      v_job.message_id, v_job.chat_id, v_job.viewer_id,
      v_job.learning_language, v_job.primary_known_language,
      v_job.language_revision, v_job.source_version, 'ready',
      v_cached.translation_text, v_cached.interface_text,
      v_cached.source_lang, v_cached.aid_mode, v_cached.explanation,
      v_cached.confidence, v_cached.tokens, v_cached.form_alternatives,
      null, now()
    )
    on conflict (
      message_id, viewer_id, learning_language, primary_known_language,
      language_revision, source_version
    ) do update set
      status = 'ready',
      translation_text = excluded.translation_text,
      interface_text = excluded.interface_text,
      source_lang = excluded.source_lang,
      aid_mode = excluded.aid_mode,
      explanation = excluded.explanation,
      confidence = excluded.confidence,
      tokens = excluded.tokens,
      form_alternatives = excluded.form_alternatives,
      error_code = null,
      resolved_at = now();
    update public.message_preparation_jobs
    set status = 'ready', locked_at = null, last_error = null
    where id = v_job.id;
    return jsonb_build_object(
      'status', 'cached',
      'translation', v_cached.translation_text,
      'interfaceText', v_cached.interface_text,
      'mode', v_cached.aid_mode,
      'sourceLang', v_cached.source_lang,
      'interfaceLang', v_cached.interface_lang,
      'explanation', v_cached.explanation,
      'confidence', v_cached.confidence,
      'tokens', v_cached.tokens,
      'formAlternatives', v_cached.form_alternatives
    );
  end if;

  if btrim(v_message.body) = '' or char_length(btrim(v_message.body)) > 2000 then
    return jsonb_build_object('status', 'not_eligible');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'speaker', case when ctx.sender_id = v_job.viewer_id then 'viewer' else 'partner' end,
    'text', btrim(ctx.body)) order by ctx.created_at, ctx.id), '[]'::jsonb)
    into v_context
  from (
    select m.id, m.sender_id, m.body, m.created_at
    from public.messages m
    where m.chat_id = v_job.chat_id
      and m.deleted_at is null
      and m.created_at < v_message.created_at
      and btrim(m.body) <> ''
      and m.body ~ '[[:alnum:]]'
      and (v_era.started_at is null or m.created_at >= v_era.started_at)
    order by m.created_at desc, m.id desc
    limit 8
  ) ctx;

  return jsonb_build_object(
    'status', 'ready',
    'jobId', v_job.id,
    'requesterId', v_job.viewer_id,
    'messageId', v_job.message_id,
    'text', btrim(v_message.body),
    'context', v_context,
    'formContext', v_form_context,
    'sourceLang', 'auto',
    'targetLang', v_job.learning_language,
    'interfaceLang', v_job.primary_known_language,
    'sourceHash', v_job.source_version
  );
end;
$$;

revoke all on function public.request_message_translation_job(uuid)
  from public, anon, authenticated;
grant execute on function public.request_message_translation_job(uuid)
  to service_role;
