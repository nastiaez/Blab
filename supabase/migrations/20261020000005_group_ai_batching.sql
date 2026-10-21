-- Topic7420 /14578: private group variants, message-level leases, no 1:1 changes.
-- The readable result must bind to the same historical era as the worker.
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
  v_group boolean;
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

  select chat_kind='group' into v_group from public.chats where id=v_job.chat_id;

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

  if v_group then
    select p.display_name,p.grammatical_form into v_partner_name,v_partner_form
      from public.profiles p where p.id=v_message.sender_id;
    v_form_context := v_form_context || jsonb_build_object(
      'group',true,'authorName',v_partner_name,'authorForm',v_partner_form,
      'viewerName',case when v_message.sender_id=v_job.viewer_id then v_partner_name else 'group' end,
      'partnerName',case when v_message.sender_id=v_job.viewer_id then 'group' else v_partner_name end,
      'viewerForm',case when v_message.sender_id=v_job.viewer_id then v_partner_form else null end,
      'partnerForm',case when v_message.sender_id=v_job.viewer_id then null else v_partner_form end);
  end if;

  select * into v_cached
  from public.message_translations mt
  where not v_group and mt.message_id = v_job.message_id
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

  v_context := public.translation_recent_context(
    v_job.message_id, v_job.viewer_id, v_era.started_at
  );
  if v_group then
    with eligible as (
      select m.* from public.messages m where m.chat_id=v_job.chat_id and m.deleted_at is null
       and m.created_at<v_message.created_at and btrim(m.body)<>''
       and (v_era.started_at is null or m.created_at>=v_era.started_at)
    ), chosen as (
      select * from eligible where id in(select id from eligible order by created_at desc,id desc limit 2)
       or id=v_message.reply_to
    )
    select coalesce(jsonb_agg(jsonb_build_object(
      'speaker',case when m.sender_id=v_job.viewer_id then 'viewer' else 'partner' end,
      'speakerName',p.display_name,'text',btrim(m.body),'isReply',m.id=v_message.reply_to
    ) order by m.created_at,m.id),'[]'::jsonb) into v_context
    from chosen m join public.profiles p on p.id=m.sender_id;
  end if;


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
    'sourceHash', v_job.source_version,
    'languageRevision', v_job.language_revision
  );
end;
$$;

revoke all on function public.request_message_translation_job(uuid)
  from public, anon, authenticated;
grant execute on function public.request_message_translation_job(uuid)
  to service_role;


alter function public.request_message_translation_variant(uuid,text,boolean) rename to request_message_translation_variant_direct;
revoke all on function public.request_message_translation_variant_direct(uuid,text,boolean) from public,anon,authenticated;
create function public.request_message_translation_variant(p_message_id uuid,p_target_lang text default null,p_force_refresh boolean default false)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare m public.messages%rowtype; cm public.chat_members%rowtype; p public.profiles%rowtype;
 k public.message_prepared_packages%rowtype; target text; known text; era record;
begin
 select * into m from public.messages where id=p_message_id;
 if not exists(select 1 from public.chats where id=m.chat_id and chat_kind='group') then
  return public.request_message_translation_variant_direct(p_message_id,p_target_lang,p_force_refresh);
 end if;
 if not public.is_account_active(auth.uid()) or not public.group_ai_eligible(p_message_id,auth.uid()) or m.deleted_at is not null then
  return jsonb_build_object('status','forbidden');
 end if;
 select * into cm from public.chat_members where chat_id=m.chat_id and user_id=auth.uid();
 select * into era from public.resolve_message_learning_era(p_message_id,auth.uid());
 if not found then return jsonb_build_object('status','forbidden'); end if;
 select * into p from public.profiles where id=auth.uid();
 known:=coalesce(p.primary_known_language,p.interface_language,'en');
 target:=coalesce(p_target_lang,case when cm.mode='practice' then era.learning_language else known end);
 if target not in (era.learning_language,known) then return jsonb_build_object('status','not_eligible'); end if;
 select * into k from public.message_prepared_packages where message_id=m.id and viewer_id=auth.uid()
  and learning_language=era.learning_language and primary_known_language=known and language_revision=era.language_revision
  and source_version=encode(digest(convert_to(btrim(m.body),'UTF8'),'sha256'),'hex') and status='ready';
 if found then return jsonb_build_object('status','cached','mode',k.aid_mode,
  'translation',case when target=era.learning_language then k.translation_text else k.interface_text end,
  'interfaceText',k.interface_text,'sourceLang',k.source_lang,'interfaceLang',known,'targetLang',target,
  'tokens',case when target=era.learning_language then k.tokens else '[]'::jsonb end,
  'explanation',k.explanation,'confidence',k.confidence,'formAlternatives',k.form_alternatives,'languageRevision',era.language_revision);
 end if;
 perform public.enqueue_message_preparation_jobs(m.id);
 if p_force_refresh then
  update public.message_preparation_jobs set status='queued',attempts=0,available_at=clock_timestamp(),last_error=null
   where message_id=m.id and viewer_id=auth.uid() and status='failed' and language_revision=era.language_revision;
 end if;
 if exists(select 1 from public.message_preparation_jobs where message_id=m.id and viewer_id=auth.uid() and status='failed'
   and language_revision=era.language_revision) then return jsonb_build_object('status','failed','reason','preparation_failed'); end if;
 return jsonb_build_object('status','pending');
end; $$;
revoke all on function public.request_message_translation_variant(uuid,text,boolean) from public,anon;
grant execute on function public.request_message_translation_variant(uuid,text,boolean) to authenticated;

-- Suppress unscoped legacy cache writes for group messages. Their explicit private
-- package/readable writes below remain authoritative; 1:1 triggers are unchanged.
create function public.skip_group_legacy_translation() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if exists(select 1 from public.messages m join public.chats c on c.id=m.chat_id
  where m.id=new.message_id and c.chat_kind='group') then return null; end if;
 return new;
end; $$;
create trigger a_skip_group_legacy_translation before insert or update on public.message_translations
 for each row execute function public.skip_group_legacy_translation();
revoke all on function public.skip_group_legacy_translation() from public,anon,authenticated;

create table public.group_translation_artifacts (
 message_id uuid not null references public.messages(id) on delete cascade,
 variant_key text not null check(variant_key ~ '^[0-9a-f]{64}$'),
 source_hash text not null,
 result jsonb not null,
 primary key(message_id,variant_key)
);
alter table public.group_translation_artifacts enable row level security;
revoke all on public.group_translation_artifacts from public,anon,authenticated;
create function public.group_translation_artifact(p_message_id uuid,p_variant_key text,p_source_hash text,p_result jsonb default null)
returns jsonb language plpgsql security definer set search_path=public,extensions as $$
declare r jsonb;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 if not exists(select 1 from public.messages m join public.chats c on c.id=m.chat_id
  where m.id=p_message_id and c.chat_kind='group' and m.deleted_at is null
   and encode(digest(convert_to(btrim(m.body),'UTF8'),'sha256'),'hex')=p_source_hash) then return null; end if;
 if p_result is not null then
  r:=public.normalize_translation_storage_result(p_result);
  if r is null then raise exception 'invalid_artifact'; end if;
  insert into public.group_translation_artifacts values(p_message_id,p_variant_key,p_source_hash,r)
   on conflict(message_id,variant_key) do nothing;
 end if;
 select result into r from public.group_translation_artifacts where message_id=p_message_id
  and variant_key=p_variant_key and source_hash=p_source_hash;
 return r;
end; $$;
revoke all on function public.group_translation_artifact(uuid,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.group_translation_artifact(uuid,text,text,jsonb) to service_role;

-- Reserve messages, not viewers. A group cannot monopolize every global slot
-- or be skipped just because it has more than four members.
create or replace function public.claim_message_preparation_jobs_for_worker(p_limit integer default 10)
returns setof public.message_preparation_jobs
language plpgsql security definer set search_path=public,extensions as $$
declare capacity integer; chosen uuid;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 if not pg_try_advisory_xact_lock(hashtext('blab_message_preparation_claim')) then return; end if;
 update public.message_preparation_jobs set status=case when attempts>=4 then 'failed' else 'queued' end,
  locked_at=null,lease_token=null,available_at=clock_timestamp(),last_error='lease_expired'
  where status='processing' and locked_at<clock_timestamp()-interval '45 seconds';
 select greatest(0,4-count(distinct message_id))::integer into capacity
  from public.message_preparation_jobs where status='processing';
 if capacity=0 then return; end if;
 select j.message_id into chosen from public.message_preparation_jobs j join public.messages m on m.id=j.message_id
  where j.status='queued' and j.available_at<=clock_timestamp()
   and not exists(select 1 from public.message_preparation_jobs busy where busy.message_id=j.message_id and busy.status='processing')
  order by m.created_at,m.id,j.id limit 1;
 if chosen is null then return; end if;
 return query update public.message_preparation_jobs set status='processing',locked_at=clock_timestamp(),
  lease_token=gen_random_uuid(),attempts=attempts+1 where message_id=chosen and status='queued' and available_at<=clock_timestamp() returning *;
end; $$;

create function public.renew_message_preparation_leases(p_leases jsonb) returns boolean
language plpgsql security definer set search_path=public as $$
declare expected integer; changed integer;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 expected:=jsonb_array_length(p_leases);
 update public.message_preparation_jobs j set locked_at=clock_timestamp()
 from jsonb_to_recordset(p_leases) as x(id uuid,lease uuid)
 where j.id=x.id and j.lease_token=x.lease and j.status='processing';
 get diagnostics changed=row_count;
 return changed=expected;
end; $$;
revoke all on function public.renew_message_preparation_leases(jsonb) from public,anon,authenticated;
grant execute on function public.renew_message_preparation_leases(jsonb) to service_role;

-- Rebind legacy interactive entry points to the group-aware queue owner.
create or replace function public.request_message_translation(p_message_id uuid)
returns jsonb language sql security definer set search_path=public,extensions as $$
 select public.request_message_translation_variant(p_message_id,null,false);
$$;
create or replace function public.request_message_translation_fresh(p_message_id uuid)
returns jsonb language sql security definer set search_path=public,extensions as $$
 select public.request_message_translation_variant(p_message_id,null,true);
$$;
