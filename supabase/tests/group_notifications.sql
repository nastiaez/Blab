begin;
update public.app_distribution_policy set channel='public';
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
select set_config('test.group',(select chat_id::text from public.create_group('Notification QA')),true);
select set_config('test.invite',(select token from public.create_group_invite(current_setting('test.group')::uuid)),true);
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
select public.join_group(current_setting('test.invite'));
select public.set_group_notifications(current_setting('test.group')::uuid,false);
do $$begin
  if (select notifications_enabled from public.chat_members where chat_id=current_setting('test.group')::uuid and user_id=auth.uid()) then raise exception 'mute not saved'; end if;
  if not (select notifications_enabled from public.chat_members where chat_id=current_setting('test.group')::uuid and user_id='00000000-0000-4000-8000-00000000000a') then raise exception 'changed other member'; end if;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
insert into public.messages(chat_id,sender_id,body) values(current_setting('test.group')::uuid,auth.uid(),'muted');
reset role;
do $$begin
  if exists(select 1 from public.push_notification_events where chat_id=current_setting('test.group')::uuid) then raise exception 'muted push enqueued'; end if;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
set local role authenticated;
select public.set_group_notifications(current_setting('test.group')::uuid,true);
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
insert into public.messages(chat_id,sender_id,body) values(current_setting('test.group')::uuid,auth.uid(),'unmuted');
reset role;
select set_config('test.event',(select id::text from public.push_notification_events where chat_id=current_setting('test.group')::uuid),true);
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
set local role authenticated;
select public.set_group_notifications(current_setting('test.group')::uuid,false);
reset role;
set local role service_role;
do $$begin
  if exists(select 1 from public.claim_push_notification_event(current_setting('test.event')::uuid)) then raise exception 'queued push bypassed mute'; end if;
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000c"}',true);
set local role authenticated;
do $$begin
  begin
    perform public.set_group_notifications(current_setting('test.group')::uuid,false);
    raise exception 'outsider changed notifications';
  exception when insufficient_privilege then null; end;
end $$;
rollback;
