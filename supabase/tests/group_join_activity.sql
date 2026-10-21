begin;
update public.app_distribution_policy set channel='public',testing_enabled=true;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
select set_config('test.group',(select chat_id::text from public.create_group('Join activity proof')),true);
select set_config('test.token',(select token from public.create_group_invite(current_setting('test.group')::uuid)),true);
insert into public.messages(chat_id,sender_id,body) values(current_setting('test.group')::uuid,auth.uid(),'Older original');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
select * from public.join_group(current_setting('test.token'));
select * from public.join_group(current_setting('test.token'));
do $$declare event_id uuid; begin
 if (select count(*) from public.messages where chat_id=current_setting('test.group')::uuid and message_type='group_joined')<>1 then raise exception 'duplicate or missing activity'; end if;
 select id into event_id from public.messages where chat_id=current_setting('test.group')::uuid and message_type='group_joined';
 if public.group_ai_eligible(event_id,auth.uid()) then raise exception 'activity AI eligible'; end if;
 if exists(select 1 from public.unread_message_ids(current_setting('test.group')::uuid)) then raise exception 'old history or join counted unread'; end if;
 begin insert into public.messages(chat_id,sender_id,body,message_type) values(current_setting('test.group')::uuid,auth.uid(),'','group_joined');
  raise exception 'user forged activity'; exception when insufficient_privilege then null; end;
 begin update public.messages set body='Fake event' where id=event_id; raise exception 'user edited activity'; exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$begin
 if exists(select 1 from public.message_preparation_jobs j join public.messages m on m.id=j.message_id where m.chat_id=current_setting('test.group')::uuid and m.message_type='group_joined') then raise exception 'activity enqueued AI'; end if;
 if exists(select 1 from public.push_notification_events e join public.messages m on m.id::text=e.source_key where m.chat_id=current_setting('test.group')::uuid and m.message_type='group_joined') then raise exception 'activity sent human message push'; end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
do $$begin
 if exists(select 1 from public.unread_message_ids(current_setting('test.group')::uuid)) then raise exception 'join counts as unread for owner'; end if;
 if (select last_body from public.chat_list where chat_id=current_setting('test.group')::uuid)<>'Older original' then raise exception 'activity replaced chat preview'; end if;
end $$;
select public.remove_group_member(current_setting('test.group')::uuid,'00000000-0000-4000-8000-00000000000b');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
do $$begin
 if not exists(select 1 from public.group_departures where chat_id=current_setting('test.group')::uuid) then raise exception 'revocation hint unavailable'; end if;
 if exists(select 1 from public.messages where chat_id=current_setting('test.group')::uuid) then raise exception 'removed member retained group content'; end if;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000c"}',true);
do $$begin
 if exists(select 1 from public.group_departures where chat_id=current_setting('test.group')::uuid) then raise exception 'other user revocation hint leaked'; end if;
end $$;
rollback;
