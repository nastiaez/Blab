-- Keep every viewer/language variant independently addressable. A primary
-- known-language change must not overwrite the package produced for the
-- previous pair at the same learning-language revision.
alter table public.message_prepared_packages
  drop constraint if exists message_prepared_packages_pkey;
alter table public.message_prepared_packages
  add primary key (
    message_id,
    viewer_id,
    learning_language,
    primary_known_language,
    language_revision,
    source_version
  );

alter table public.message_preparation_jobs
  drop constraint if exists message_preparation_jobs_message_id_viewer_id_language_revision_source_version_key;
alter table public.message_preparation_jobs
  add constraint message_preparation_jobs_variant_key unique (
    message_id,
    viewer_id,
    learning_language,
    primary_known_language,
    language_revision,
    source_version
  );

create or replace function public.enqueue_message_preparation_jobs(
  p_message_id uuid
) returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_message public.messages%rowtype;
  v_source_version text;
begin
  select * into v_message
  from public.messages
  where id = p_message_id and deleted_at is null;
  if not found then return; end if;
  if coalesce(v_message.message_type, 'text') = 'image'
      and btrim(coalesce(v_message.body, '')) = '' then
    return;
  end if;

  v_source_version := encode(
    digest(convert_to(btrim(v_message.body), 'UTF8'), 'sha256'),
    'hex'
  );

  insert into public.message_preparation_jobs (
    message_id, chat_id, viewer_id, learning_language,
    primary_known_language, language_revision, source_version
  )
  select
    v_message.id,
    cm.chat_id,
    cm.user_id,
    cm.learning_language,
    coalesce(p.primary_known_language, p.interface_language, 'en'),
    cm.learning_language_revision,
    v_source_version
  from public.chat_members cm
  join public.profiles p on p.id = cm.user_id
  where cm.chat_id = v_message.chat_id
  on conflict (
    message_id, viewer_id, learning_language, primary_known_language,
    language_revision, source_version
  ) do nothing;
end;
$$;

revoke all on function public.enqueue_message_preparation_jobs(uuid)
  from public, anon, authenticated;

create or replace function public.sync_prepared_package_from_translation()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  insert into public.message_prepared_packages (
    message_id, chat_id, viewer_id, learning_language,
    primary_known_language, language_revision, source_version, status,
    translation_text, interface_text, source_lang, aid_mode, explanation,
    confidence, tokens, form_alternatives, resolved_at
  )
  select
    new.message_id,
    m.chat_id,
    cm.user_id,
    cm.learning_language,
    coalesce(p.primary_known_language, p.interface_language, 'en'),
    cm.learning_language_revision,
    new.source_hash,
    'ready',
    new.translation_text,
    new.interface_text,
    new.source_lang,
    new.aid_mode,
    new.explanation,
    new.confidence,
    new.tokens,
    new.form_alternatives,
    now()
  from public.messages m
  join public.chat_members cm on cm.chat_id = m.chat_id
  join public.profiles p on p.id = cm.user_id
  where m.id = new.message_id
    and cm.learning_language = new.target_lang
    and coalesce(p.primary_known_language, p.interface_language, 'en') =
      new.interface_lang
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
    resolved_at = now();
  return new;
end;
$$;

revoke all on function public.sync_prepared_package_from_translation()
  from public, anon, authenticated;

create or replace function public.set_learning_language(
  p_chat_id uuid,
  p_learning_language text
) returns bigint
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_old public.chat_members%rowtype;
  v_revision bigint;
begin
  if v_uid is null or not public.is_account_active(v_uid)
      or p_learning_language not in ('nl','en','fr','de','hi','it','pt','es','ta','tr','uk') then
    raise exception 'invalid_learning_language';
  end if;
  select * into v_old
  from public.chat_members
  where chat_id = p_chat_id and user_id = v_uid
  for update;
  if not found then raise exception 'chat_membership_not_found'; end if;
  if v_old.learning_language = p_learning_language then
    return v_old.learning_language_revision;
  end if;

  v_revision := v_old.learning_language_revision + 1;
  update public.chat_members
  set learning_language = p_learning_language,
      learning_language_revision = v_revision,
      translation_cutoff_at = statement_timestamp()
  where chat_id = p_chat_id and user_id = v_uid;

  insert into public.chat_language_timeline (
    chat_id, user_id, revision, learning_language
  ) values (p_chat_id, v_uid, v_revision, p_learning_language)
  on conflict (chat_id, user_id, revision) do nothing;

  delete from public.message_preparation_jobs
  where chat_id = p_chat_id
    and viewer_id = v_uid
    and status in ('queued', 'processing');

  insert into public.message_preparation_jobs (
    message_id, chat_id, viewer_id, learning_language,
    primary_known_language, language_revision, source_version
  )
  select
    m.id, m.chat_id, v_uid, p_learning_language,
    coalesce(p.primary_known_language, p.interface_language, 'en'),
    v_revision,
    encode(digest(convert_to(btrim(m.body), 'UTF8'), 'sha256'), 'hex')
  from public.messages m
  join public.profiles p on p.id = v_uid
  where m.chat_id = p_chat_id
    and m.sender_id <> v_uid
    and m.deleted_at is null
    and not exists (
      select 1 from public.message_reads r
      where r.message_id = m.id and r.user_id = v_uid
    )
    and not (
      coalesce(m.message_type, 'text') = 'image'
      and btrim(coalesce(m.body, '')) = ''
    )
  on conflict (
    message_id, viewer_id, learning_language, primary_known_language,
    language_revision, source_version
  ) do nothing;
  return v_revision;
end;
$$;

revoke all on function public.set_learning_language(uuid, text)
  from public, anon;
grant execute on function public.set_learning_language(uuid, text)
  to authenticated;
