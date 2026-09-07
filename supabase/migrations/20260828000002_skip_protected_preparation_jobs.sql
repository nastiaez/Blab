-- Protected-only messages do not need a provider job. This keeps the durable
-- readiness queue aligned with the client rule for photo-only/empty content.
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
  on conflict (message_id, viewer_id, language_revision, source_version)
  do nothing;
end;
$$;

revoke all on function public.enqueue_message_preparation_jobs(uuid)
  from public, anon, authenticated;
