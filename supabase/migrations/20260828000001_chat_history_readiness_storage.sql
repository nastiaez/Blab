-- US-044…US-047 / FR-38…FR-41.
-- Durable viewer packages, private learning-language revisions, and media
-- preview metadata. The existing message_translations table remains the
-- provider cache; these records describe which viewer-specific variant is
-- active and give delivery a durable queue to recover from.

alter table public.chat_members
  add column if not exists learning_language_revision bigint not null default 1;

alter table public.message_attachments
  add column if not exists preview_storage_path text,
  add column if not exists preview_mime_type text,
  add column if not exists preview_byte_size integer;

create table if not exists public.chat_language_timeline (
  chat_id uuid not null references public.chats (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  revision bigint not null check (revision > 0),
  learning_language text not null,
  created_at timestamptz not null default now(),
  primary key (chat_id, user_id, revision),
  foreign key (chat_id, user_id)
    references public.chat_members (chat_id, user_id)
    on delete cascade
);

insert into public.chat_language_timeline (
  chat_id, user_id, revision, learning_language
)
select chat_id, user_id, learning_language_revision, learning_language
from public.chat_members
on conflict (chat_id, user_id, revision) do nothing;

create index if not exists chat_language_timeline_user_idx
  on public.chat_language_timeline (user_id, chat_id, revision);

alter table public.chat_language_timeline enable row level security;
revoke all on table public.chat_language_timeline from public, anon, authenticated;
grant select on table public.chat_language_timeline to authenticated;
drop policy if exists chat_language_timeline_select_self
  on public.chat_language_timeline;
create policy chat_language_timeline_select_self
  on public.chat_language_timeline
  for select to authenticated
  using (user_id = auth.uid() and public.is_account_active(auth.uid()));

create table if not exists public.message_prepared_packages (
  message_id uuid not null references public.messages (id) on delete cascade,
  chat_id uuid not null references public.chats (id) on delete cascade,
  viewer_id uuid not null references public.profiles (id) on delete cascade,
  learning_language text not null,
  primary_known_language text not null,
  language_revision bigint not null check (language_revision > 0),
  source_version text not null check (source_version ~ '^[0-9a-f]{64}$'),
  status text not null default 'pending'
    check (status in ('pending', 'ready', 'failed')),
  translation_text text,
  interface_text text,
  source_lang text,
  aid_mode text,
  explanation text,
  confidence text,
  tokens jsonb not null default '[]'::jsonb,
  form_alternatives jsonb,
  error_code text,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  primary key (message_id, viewer_id, language_revision, source_version)
);

create index if not exists message_prepared_packages_viewer_idx
  on public.message_prepared_packages (viewer_id, chat_id, language_revision, message_id);

alter table public.message_prepared_packages enable row level security;
revoke all on table public.message_prepared_packages from public, anon, authenticated;
grant select on table public.message_prepared_packages to authenticated;
drop policy if exists message_prepared_packages_select_self
  on public.message_prepared_packages;
create policy message_prepared_packages_select_self
  on public.message_prepared_packages
  for select to authenticated
  using (viewer_id = auth.uid() and public.is_account_active(auth.uid()));

create table if not exists public.message_preparation_jobs (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages (id) on delete cascade,
  chat_id uuid not null references public.chats (id) on delete cascade,
  viewer_id uuid not null references public.profiles (id) on delete cascade,
  learning_language text not null,
  primary_known_language text not null,
  language_revision bigint not null check (language_revision > 0),
  source_version text not null check (source_version ~ '^[0-9a-f]{64}$'),
  status text not null default 'queued'
    check (status in ('queued', 'processing', 'ready', 'failed')),
  attempts integer not null default 0 check (attempts >= 0),
  available_at timestamptz not null default now(),
  locked_at timestamptz,
  last_error text,
  created_at timestamptz not null default now(),
  unique (message_id, viewer_id, language_revision, source_version)
);

create index if not exists message_preparation_jobs_ready_idx
  on public.message_preparation_jobs (status, available_at, created_at);
create index if not exists message_preparation_jobs_viewer_idx
  on public.message_preparation_jobs (viewer_id, chat_id, status, created_at);

alter table public.message_preparation_jobs enable row level security;
revoke all on table public.message_preparation_jobs from public, anon, authenticated;

-- Delivery creates one job per participant in the same transaction. A worker
-- or the client recovery path can safely claim it later.
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
  on conflict (message_id, viewer_id, language_revision, source_version)
  do nothing;
end;
$$;

revoke all on function public.enqueue_message_preparation_jobs(uuid)
  from public, anon, authenticated;

create or replace function public.enqueue_message_preparation_after_insert()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  perform public.enqueue_message_preparation_jobs(new.id);
  return new;
end;
$$;

revoke all on function public.enqueue_message_preparation_after_insert()
  from public, anon, authenticated;
drop trigger if exists enqueue_message_preparation_after_insert on public.messages;
create trigger enqueue_message_preparation_after_insert
  after insert on public.messages
  for each row execute function public.enqueue_message_preparation_after_insert();

create or replace function public.record_legacy_learning_language_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_revision bigint;
begin
  if old.learning_language is distinct from new.learning_language
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

revoke all on function public.record_legacy_learning_language_change()
  from public, anon, authenticated;
drop trigger if exists record_legacy_learning_language_change
  on public.chat_members;
create trigger record_legacy_learning_language_change
  after update of learning_language on public.chat_members
  for each row execute function public.record_legacy_learning_language_change();

-- Existing translation rows become viewer packages for every matching member.
-- This also backfills readiness after a worker or client fills a cache row.
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
  on conflict (message_id, viewer_id, language_revision, source_version)
  do update set
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
drop trigger if exists sync_prepared_package_from_translation
  on public.message_translations;
create trigger sync_prepared_package_from_translation
  after insert or update on public.message_translations
  for each row execute function public.sync_prepared_package_from_translation();

-- Language changes are private to one membership. The revision is bumped
-- before pending jobs are re-assigned, so late old-language results cannot
-- become active.
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
      -- Keep the legacy cutoff for older requesters; historical viewer
      -- packages are served from message_prepared_packages instead.
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

  -- Unread partner messages are the only historical work retargeted. Future
  -- deliveries are covered by the insert trigger above.
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
  on conflict (message_id, viewer_id, language_revision, source_version)
  do nothing;
  return v_revision;
end;
$$;

revoke update (learning_language) on public.chat_members from authenticated;
-- Keep the legacy column grant for existing clients/tests; the shipped app
-- uses set_learning_language(), while the legacy cutoff trigger still keeps
-- direct updates from moving history backwards.
grant update (learning_language) on public.chat_members to authenticated;
grant execute on function public.set_learning_language(uuid, text)
  to authenticated;

-- Authenticated recovery can claim its own jobs; service workers retain the
-- broader queue privileges through the table's default service-role access.
create or replace function public.claim_message_preparation_jobs(
  p_chat_id uuid,
  p_limit integer default 20
) returns setof public.message_preparation_jobs
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  return query
  with picked as (
    select id
    from public.message_preparation_jobs
    where viewer_id = auth.uid()
      and chat_id = p_chat_id
      and status = 'queued'
      and available_at <= now()
    order by created_at, id
    limit greatest(1, least(coalesce(p_limit, 20), 50))
    for update skip locked
  )
  update public.message_preparation_jobs j
  set status = 'processing', locked_at = now(), attempts = j.attempts + 1
  from picked
  where j.id = picked.id
  returning j.*;
end;
$$;

revoke all on function public.claim_message_preparation_jobs(uuid, integer)
  from public, anon;
grant execute on function public.claim_message_preparation_jobs(uuid, integer)
  to authenticated;

-- Keep media metadata readable to members while originals/previews remain in
-- the private Storage bucket. Existing rows have no preview path and are
-- warmed from their original on the next connected fetch.
