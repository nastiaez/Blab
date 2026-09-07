-- Older clients can update chat_members directly. If that happened without a
-- matching timeline row, the legacy cutoff still identifies the start of the
-- current era; use it as a recovery boundary, never as a history deletion.
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
  where m.id = p_message_id
    and (
      p_viewer_id = auth.uid()
      or auth.role() = 'service_role'
    );
$$;

revoke all on function public.resolve_message_learning_era(uuid, uuid)
  from public, anon;
grant execute on function public.resolve_message_learning_era(uuid, uuid)
  to authenticated, service_role;
