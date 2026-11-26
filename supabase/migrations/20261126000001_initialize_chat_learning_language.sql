-- Resolve an unset membership on first open, including memberships that
-- predate language onboarding. Never replace a concurrent Settings choice.
create function public.initialize_chat_learning_language(p_chat_id uuid)
returns text language plpgsql security definer set search_path = public, pg_temp as $$
declare
  viewer uuid := auth.uid();
  membership public.chat_members%rowtype;
  chosen text;
begin
  if viewer is null or not public.is_account_active(viewer) then
    raise exception 'not_authenticated';
  end if;
  select * into strict membership from public.chat_members
    where chat_id = p_chat_id and user_id = viewer for update;
  if not exists (select 1 from public.chats where id = p_chat_id and chat_kind = 'direct') then
    raise exception 'not_direct_chat';
  end if;
  if membership.practice_language_selected_at is not null then
    return membership.learning_language;
  end if;
  select coalesce(default_learning_language, membership.learning_language)
    into strict chosen from public.profiles where id = viewer;
  perform public.set_learning_language(p_chat_id, chosen);
  return chosen;
end;
$$;
revoke all on function public.initialize_chat_learning_language(uuid) from public, anon;
grant execute on function public.initialize_chat_learning_language(uuid) to authenticated;
