-- Topic7420 /14826: retain historical learning language during known-language recovery.
create or replace function public.request_message_translation_variant(p_message_id uuid,p_target_lang text default null,p_force_refresh boolean default false)
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
 -- Interactive recovery belongs only to this viewer and the resolved era.
 -- Current membership language may differ from the completed message's era.
 insert into public.message_preparation_jobs(message_id,chat_id,viewer_id,
  learning_language,primary_known_language,language_revision,source_version)
 values(m.id,m.chat_id,auth.uid(),era.learning_language,known,era.language_revision,
  encode(digest(convert_to(btrim(m.body),'UTF8'),'sha256'),'hex'))
 on conflict(message_id,viewer_id,learning_language,primary_known_language,
  language_revision,source_version) do nothing;
 if p_force_refresh then
  update public.message_preparation_jobs set status='queued',attempts=0,available_at=clock_timestamp(),last_error=null
   where message_id=m.id and viewer_id=auth.uid() and status='failed' and language_revision=era.language_revision
    and learning_language=era.learning_language and primary_known_language=known
    and source_version=encode(digest(convert_to(btrim(m.body),'UTF8'),'sha256'),'hex');
 end if;
 if exists(select 1 from public.message_preparation_jobs where message_id=m.id and viewer_id=auth.uid() and status='failed'
   and language_revision=era.language_revision
   and learning_language=era.learning_language and primary_known_language=known
   and source_version=encode(digest(convert_to(btrim(m.body),'UTF8'),'sha256'),'hex')) then return jsonb_build_object('status','failed','reason','preparation_failed'); end if;
 return jsonb_build_object('status','pending');
end; $$;
revoke all on function public.request_message_translation_variant(uuid,text,boolean) from public,anon;
grant execute on function public.request_message_translation_variant(uuid,text,boolean) to authenticated;
