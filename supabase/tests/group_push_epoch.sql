-- Claim policy only: no actual FCM/device dispatch is performed.
begin;
update public.app_distribution_policy set channel='public',testing_enabled=true;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
select set_config('test.group',(select chat_id::text from public.create_group('Push epoch proof')),true);
select set_config('test.token',(select token from public.create_group_invite(current_setting('test.group')::uuid)),true);
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
select * from public.join_group(current_setting('test.token'));
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
insert into public.messages(chat_id,sender_id,body) values(current_setting('test.group')::uuid,auth.uid(),'Queued before departure');
reset role;
select set_config('test.event',(select id::text from public.push_notification_events
 where chat_id=current_setting('test.group')::uuid and recipient_id='00000000-0000-4000-8000-00000000000b'),true);
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
set local role authenticated;
select public.leave_group(current_setting('test.group')::uuid);
select * from public.join_group(current_setting('test.token'));
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
do $$begin
 if exists(select 1 from public.claim_push_notification_event(current_setting('test.event')::uuid)) then raise exception 'old queued push delivered after rejoin'; end if;
 if not exists(select 1 from public.push_notification_events where id=current_setting('test.event')::uuid and status='completed') then raise exception 'stale push was not settled'; end if;
end $$;
rollback;
