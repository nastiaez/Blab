-- US-046 / FR-40: every membership needs a revision-one language era.
-- The original rollout backfilled memberships that already existed when the
-- table was created, but chats created afterward had no insert trigger. Their
-- first language change therefore produced revision two as the earliest row,
-- making old messages fall back to that newer language.

create or replace function public.seed_initial_chat_language_timeline()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.learning_language_revision = 1 then
    insert into public.chat_language_timeline (
      chat_id,
      user_id,
      revision,
      learning_language,
      created_at
    ) values (
      new.chat_id,
      new.user_id,
      1,
      new.learning_language,
      new.joined_at
    )
    on conflict (chat_id, user_id, revision) do nothing;
  end if;
  return new;
end;
$$;

revoke all on function public.seed_initial_chat_language_timeline()
  from public, anon, authenticated;

drop trigger if exists seed_initial_chat_language_timeline
  on public.chat_members;
create trigger seed_initial_chat_language_timeline
  after insert on public.chat_members
  for each row execute function public.seed_initial_chat_language_timeline();

-- Protect memberships created before this trigger but not switched yet. The
-- old row is still the authoritative initial language at the first change.
create or replace function public.ensure_initial_timeline_before_language_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.learning_language_revision = 1
      and old.learning_language is distinct from new.learning_language then
    insert into public.chat_language_timeline (
      chat_id,
      user_id,
      revision,
      learning_language,
      created_at
    ) values (
      old.chat_id,
      old.user_id,
      1,
      old.learning_language,
      old.joined_at
    )
    on conflict (chat_id, user_id, revision) do nothing;
  end if;
  return new;
end;
$$;

revoke all on function public.ensure_initial_timeline_before_language_change()
  from public, anon, authenticated;

drop trigger if exists ensure_initial_timeline_before_language_change
  on public.chat_members;
create trigger ensure_initial_timeline_before_language_change
  before update of learning_language on public.chat_members
  for each row execute function public.ensure_initial_timeline_before_language_change();

-- Repair affected memberships when revision-one preparation records still
-- preserve the original language. Memberships that have not switched can use their
-- current value directly. Do not guess for switched history with no evidence.
with inferred_initial_language as (
  select
    cm.chat_id,
    cm.user_id,
    cm.joined_at,
    coalesce(
      (
        select package.learning_language
        from public.message_prepared_packages package
        where package.chat_id = cm.chat_id
          and package.viewer_id = cm.user_id
          and package.language_revision = 1
        order by package.created_at asc, package.message_id asc
        limit 1
      ),
      (
        select job.learning_language
        from public.message_preparation_jobs job
        where job.chat_id = cm.chat_id
          and job.viewer_id = cm.user_id
          and job.language_revision = 1
        order by job.created_at asc, job.id asc
        limit 1
      ),
      case
        when cm.learning_language_revision = 1 then cm.learning_language
      end
    ) as learning_language
  from public.chat_members cm
  where not exists (
    select 1
    from public.chat_language_timeline timeline
    where timeline.chat_id = cm.chat_id
      and timeline.user_id = cm.user_id
      and timeline.revision = 1
  )
)
insert into public.chat_language_timeline (
  chat_id,
  user_id,
  revision,
  learning_language,
  created_at
)
select
  inferred.chat_id,
  inferred.user_id,
  1,
  inferred.learning_language,
  inferred.joined_at
from inferred_initial_language inferred
where inferred.learning_language is not null
on conflict (chat_id, user_id, revision) do nothing;
