begin;
update public.app_distribution_policy set channel='public';
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
select set_config('test.group',(select chat_id::text from public.create_group('Media history QA')),true);
select set_config('test.invite',(select token from public.create_group_invite(current_setting('test.group')::uuid)),true);
insert into public.messages(chat_id,sender_id,body,message_type)
  values(current_setting('test.group')::uuid,auth.uid(),'','image');
select set_config('test.old',(select id::text from public.messages where chat_id=current_setting('test.group')::uuid),true);
select set_config('test.path',current_setting('test.group')||'/'||auth.uid()::text||'/before.png',true);
do $$begin
  if not public.group_storage_history_visible('message-media',current_setting('test.path'))
    then raise exception 'uploader cannot upsert before attachment metadata'; end if;
end $$;
insert into public.message_attachments(message_id,chat_id,storage_path,mime_type,byte_size)
  values(current_setting('test.old')::uuid,current_setting('test.group')::uuid,current_setting('test.path'),'image/png',100);
reset role;
insert into storage.objects(bucket_id,name) values('message-media',current_setting('test.path'));
set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
select public.join_group(current_setting('test.invite'));
do $$begin
  if not exists(select 1 from public.message_attachments where chat_id=current_setting('test.group')::uuid)
    then raise exception 'original photo metadata missing'; end if;
  if not exists(select 1 from storage.objects where name=current_setting('test.path'))
    then raise exception 'original photo object missing'; end if;
  if not public.group_message_history_visible(current_setting('test.old')::uuid)
    then raise exception 'original photo denied';
  end if;
  if public.group_ai_eligible(current_setting('test.old')::uuid,auth.uid())
    then raise exception 'historical photo AI eligible'; end if;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
do $$begin
  if (select count(*) from public.message_attachments where chat_id=current_setting('test.group')::uuid)<>1
    then raise exception 'author lost photo metadata'; end if;
  if not public.group_storage_history_visible('message-media',current_setting('test.path'))
    then raise exception 'author lost photo access'; end if;
end$$;
insert into public.messages(chat_id,sender_id,body,message_type)
  values(current_setting('test.group')::uuid,auth.uid(),'','image');
select set_config('test.new',(select id::text from public.messages where chat_id=current_setting('test.group')::uuid
  and id<>current_setting('test.old')::uuid and message_type='image'),true);
insert into public.message_attachments(message_id,chat_id,storage_path,mime_type,byte_size)
  values(current_setting('test.new')::uuid,current_setting('test.group')::uuid,current_setting('test.group')||'/'||auth.uid()::text||'/after.png','image/png',100);
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
do $$begin
  if (select count(*) from public.message_attachments where chat_id=current_setting('test.group')::uuid)<>2
    then raise exception 'original media history incomplete'; end if;
end$$;
rollback;
