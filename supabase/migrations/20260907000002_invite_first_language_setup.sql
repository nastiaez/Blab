-- US-027 / FR-22: initial selection establishes history; later changes retain it.
-- Legacy language-first membership inserts remain configured; claim_invite
-- explicitly inserts null for both participants in the new connection flow.
alter table public.chat_members
  alter column practice_language_selected_at set default now();

create or replace function public.set_translation_cutoff_on_language_change()
returns trigger language plpgsql set search_path = public as $$
begin
  if old.practice_language_selected_at is null then
    new.practice_language_selected_at := statement_timestamp();
    new.translation_cutoff_at := null;
  else
    new.practice_language_selected_at := old.practice_language_selected_at;
    if old.learning_language is distinct from new.learning_language then
      new.translation_cutoff_at := statement_timestamp();
    else
      new.translation_cutoff_at := old.translation_cutoff_at;
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.record_legacy_learning_language_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_revision bigint;
begin
  if old.practice_language_selected_at is not null
      and old.learning_language is distinct from new.learning_language
      and old.learning_language_revision = new.learning_language_revision then
    v_revision := old.learning_language_revision + 1;
    update public.chat_members
    set learning_language_revision = v_revision
    where chat_id = new.chat_id and user_id = new.user_id;
    insert into public.chat_language_timeline (
      chat_id, user_id, revision, learning_language
    ) values (new.chat_id, new.user_id, v_revision, new.learning_language)
    on conflict (chat_id, user_id, revision) do nothing;
  end if;
  return new;
end;
$$;

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
  if v_old.practice_language_selected_at is null then
    update public.chat_members
    set learning_language = p_learning_language,
        practice_language_selected_at = statement_timestamp()
    where chat_id = p_chat_id and user_id = v_uid;

    insert into public.chat_language_timeline (
      chat_id, user_id, revision, learning_language, created_at
    ) values (p_chat_id, v_uid, v_old.learning_language_revision,
              p_learning_language, v_old.joined_at)
    on conflict (chat_id, user_id, revision) do update
      set learning_language = excluded.learning_language,
          created_at = excluded.created_at;

    delete from public.message_preparation_jobs
    where chat_id = p_chat_id and viewer_id = v_uid;
    delete from public.message_prepared_packages
    where chat_id = p_chat_id and viewer_id = v_uid;

    insert into public.message_preparation_jobs (
      message_id, chat_id, viewer_id, learning_language,
      primary_known_language, language_revision, source_version
    )
    select m.id, m.chat_id, v_uid, p_learning_language,
      coalesce(p.primary_known_language, p.interface_language, 'en'),
      v_old.learning_language_revision,
      encode(digest(convert_to(btrim(m.body), 'UTF8'), 'sha256'), 'hex')
    from public.messages m
    join public.profiles p on p.id = v_uid
    where m.chat_id = p_chat_id and m.deleted_at is null
      and not (coalesce(m.message_type, 'text') = 'image'
               and btrim(coalesce(m.body, '')) = '')
    on conflict (message_id, viewer_id, learning_language,
      primary_known_language, language_revision, source_version) do nothing;
    return v_old.learning_language_revision;
  end if;
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
  return v_revision;
end;
$$;

revoke all on function public.set_learning_language(uuid, text)
  from public, anon;
grant execute on function public.set_learning_language(uuid, text)
  to authenticated;

create or replace function public.resolve_message_learning_era(
  p_message_id uuid,
  p_viewer_id uuid
) returns table (
  learning_language text,
  language_revision bigint,
  started_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    case
      when cm.translation_cutoff_at is not null
        and m.created_at >= cm.translation_cutoff_at
      then cm.learning_language
      else coalesce(
        (
          select t.learning_language
          from public.chat_language_timeline t
          where t.chat_id = m.chat_id
            and t.user_id = p_viewer_id
            and t.created_at <= m.created_at
          order by t.created_at desc, t.revision desc
          limit 1
        ),
        (
          select t.learning_language
          from public.chat_language_timeline t
          where t.chat_id = m.chat_id
            and t.user_id = p_viewer_id
          order by t.revision asc
          limit 1
        ),
        cm.learning_language
      )
    end as learning_language,
    case
      when cm.translation_cutoff_at is not null
        and m.created_at >= cm.translation_cutoff_at
      then cm.learning_language_revision
      else coalesce(
        (
          select t.revision
          from public.chat_language_timeline t
          where t.chat_id = m.chat_id
            and t.user_id = p_viewer_id
            and t.created_at <= m.created_at
          order by t.created_at desc, t.revision desc
          limit 1
        ),
        (
          select t.revision
          from public.chat_language_timeline t
          where t.chat_id = m.chat_id
            and t.user_id = p_viewer_id
          order by t.revision asc
          limit 1
        ),
        cm.learning_language_revision
      )
    end as language_revision,
    case
      when cm.translation_cutoff_at is not null
        and m.created_at >= cm.translation_cutoff_at
      then cm.translation_cutoff_at
      else (
        select t.created_at
        from public.chat_language_timeline t
        where t.chat_id = m.chat_id
          and t.user_id = p_viewer_id
          and t.created_at <= m.created_at
        order by t.created_at desc, t.revision desc
        limit 1
      )
    end as started_at
  from public.messages m
  join public.chat_members cm
    on cm.chat_id = m.chat_id
   and cm.user_id = p_viewer_id
  where cm.practice_language_selected_at is not null
    and m.id = p_message_id
    and (
      p_viewer_id = auth.uid()
      or auth.role() = 'service_role'
    );
$$;

revoke all on function public.resolve_message_learning_era(uuid, uuid)
  from public, anon;
grant execute on function public.resolve_message_learning_era(uuid, uuid)
  to authenticated, service_role;
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
    and cm.practice_language_selected_at is not null
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
    and cm.practice_language_selected_at is not null
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

-- Discard work scheduled against the pre-choice placeholder by older clients.
delete from public.message_preparation_jobs j
using public.chat_members cm
where cm.chat_id = j.chat_id and cm.user_id = j.viewer_id
  and cm.practice_language_selected_at is null;
delete from public.message_prepared_packages p
using public.chat_members cm
where cm.chat_id = p.chat_id and cm.user_id = p.viewer_id
  and cm.practice_language_selected_at is null;

create or replace view public.chat_list with (security_invoker = true) as
select
  me.user_id                              as viewer_id,
  me.chat_id                              as chat_id,
  partner.user_id                         as partner_id,
  partner_profile.display_name            as partner_name,
  partner_profile.avatar_path             as partner_avatar,
  me.learning_language                    as my_learning,
  partner.learning_language               as partner_learning,
  me.mode                                 as my_mode,
  last_msg.body                           as last_body,
  coalesce(last_msg.created_at, c.created_at) as last_at,
  coalesce(unread.cnt, 0)                 as unread_count,
  last_msg.id                             as last_message_id,
  me.translation_cutoff_at                as translation_cutoff_at,
  me.practice_language_selected_at is null
                                          as needs_practice_language_selection,
  prepared.translation_text               as last_practice_body
from public.chat_members me
join public.chats c on c.id = me.chat_id
join public.profiles viewer_profile on viewer_profile.id = me.user_id
join public.chat_members partner
  on partner.chat_id = me.chat_id and partner.user_id <> me.user_id
join public.profiles partner_profile
  on partner_profile.id = partner.user_id
left join lateral (
  select id, body, created_at
  from public.messages m
  where m.chat_id = me.chat_id and m.deleted_at is null
  order by m.created_at desc
  limit 1
) last_msg on true
left join lateral (
  select package.translation_text
  from public.message_prepared_packages package
  join public.resolve_message_learning_era(last_msg.id, me.user_id) era
    on era.learning_language = package.learning_language
   and era.language_revision = package.language_revision
  where package.message_id = last_msg.id
    and package.viewer_id = me.user_id
    and me.practice_language_selected_at is not null
    and package.status = 'ready'
    and package.source_version = encode(extensions.digest(
      convert_to(btrim(last_msg.body), 'UTF8'), 'sha256'), 'hex')
    and package.primary_known_language = coalesce(
      viewer_profile.primary_known_language, viewer_profile.interface_language, 'en')
  limit 1
) prepared on true
left join lateral (
  select count(*)::int as cnt
  from public.messages m
  where m.chat_id = me.chat_id
    and m.sender_id <> me.user_id
    and m.deleted_at is null
    and not exists (
      select 1 from public.message_reads r
      where r.message_id = m.id and r.user_id = me.user_id
    )
) unread on true
where me.user_id = auth.uid();
