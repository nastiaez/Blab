-- Form changes must be able to re-evaluate a previously cached sentence.
create or replace function public.request_message_translation_fresh(
  p_message_id uuid
) returns jsonb
language plpgsql security definer
set search_path = public, extensions
as $$
declare
  v_uid uuid := auth.uid();
  v_chat_id uuid;
  v_mode text;
  v_learning_lang text;
  v_primary_known text;
  v_interface_fallback text;
  v_target_lang text;
  v_interface_lang text;
begin
  select m.chat_id, cm.mode, cm.learning_language,
         p.primary_known_language, p.interface_language
    into v_chat_id, v_mode, v_learning_lang,
         v_primary_known, v_interface_fallback
  from public.messages m
  join public.chat_members cm on cm.chat_id = m.chat_id and cm.user_id = v_uid
  join public.profiles p on p.id = v_uid
  where m.id = p_message_id and m.deleted_at is null;

  if v_uid is null or v_chat_id is null or not public.is_chat_member(v_chat_id) then
    return jsonb_build_object('status', 'forbidden');
  end if;

  v_target_lang := case when v_mode = 'practice'
    then v_learning_lang else coalesce(v_primary_known, v_interface_fallback) end;
  v_interface_lang := coalesce(v_primary_known, v_interface_fallback);

  delete from public.message_translations
  where message_id = p_message_id
    and target_lang = v_target_lang
    and interface_lang = v_interface_lang;

  return public.request_message_translation(p_message_id);
end;
$$;

revoke all on function public.request_message_translation_fresh(uuid) from public;
grant execute on function public.request_message_translation_fresh(uuid) to authenticated;
