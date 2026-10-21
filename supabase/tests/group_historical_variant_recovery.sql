-- Rollback-only regression: historical learning language, current meanings.
begin;
update public.app_distribution_policy set channel='public',testing_enabled=true;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
update public.profiles set primary_known_language='en',known_languages=array['en'] where id=auth.uid();
select set_config('test.group',(select chat_id::text from public.create_group('Historical variant recovery')),true);
select public.set_learning_language(current_setting('test.group')::uuid,'de');
insert into public.messages(chat_id,sender_id,body)
values(current_setting('test.group')::uuid,auth.uid(),'Hello everyone')
returning set_config('test.message',id::text,true);
reset role;
insert into public.message_prepared_packages(message_id,chat_id,viewer_id,
 learning_language,primary_known_language,language_revision,source_version,status,
 translation_text,interface_text,source_lang,aid_mode,tokens,resolved_at)
select m.id,m.chat_id,cm.user_id,'de','en',cm.learning_language_revision,
 encode(extensions.digest(convert_to(btrim(m.body),'UTF8'),'sha256'),'hex'),'ready',
 'Hallo zusammen','Hello everyone','en','translation','[]'::jsonb,clock_timestamp()
from public.messages m join public.chat_members cm on cm.chat_id=m.chat_id
where m.id=current_setting('test.message')::uuid;
set local role authenticated;
select public.set_learning_language(current_setting('test.group')::uuid,'es');
update public.profiles set primary_known_language='uk',known_languages=array['uk'] where id=auth.uid();
reset role;
update public.message_preparation_jobs set status='failed',last_error='old_variant_failure'
 where message_id=current_setting('test.message')::uuid and primary_known_language='en';
set local role authenticated;
do $$begin
 if public.request_message_translation_variant(current_setting('test.message')::uuid)->>'status'<>'pending' then
  raise exception 'old known-language failure blocked current variant';
 end if;
end $$;
select public.request_message_translation_variant(current_setting('test.message')::uuid);
reset role;
do $$declare era record; begin
 select * into era from public.resolve_message_learning_era(current_setting('test.message')::uuid,'00000000-0000-4000-8000-00000000000a');
 if era.learning_language<>'de' then raise exception 'fixture lost historical language'; end if;
 if not exists(select 1 from public.message_preparation_jobs
  where message_id=current_setting('test.message')::uuid and learning_language='de'
   and primary_known_language='uk' and language_revision=era.language_revision and status='queued') then
  raise exception 'historical known-language refresh queued wrong learning era';
 end if;
end $$;
rollback;
