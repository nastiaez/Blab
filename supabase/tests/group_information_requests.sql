begin;
update public.app_distribution_policy set channel='public';
delete from public.chats where chat_kind='direct' and member_low_id in (
 '00000000-0000-4000-8000-00000000000a','00000000-0000-4000-8000-00000000000b');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
select set_config('test.group',(select chat_id::text from public.create_group('QA group')),true);
select set_config('test.invite',(select token from public.create_group_invite(current_setting('test.group')::uuid)),true);
do $$begin
 if (select count(*) from public.group_members(current_setting('test.group')::uuid))<>1 then raise exception 'wrong roster'; end if;
end$$;
select public.rename_group(current_setting('test.group')::uuid,'Weekend');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
do $$begin
 begin perform public.group_members(current_setting('test.group')::uuid); raise exception 'outsider roster'; exception when insufficient_privilege then null; end;
end$$;
select public.join_group(current_setting('test.invite'));
do $$begin
 begin perform public.rename_group(current_setting('test.group')::uuid,'Hacked'); raise exception 'nonowner renamed'; exception when insufficient_privilege then null; end;
end$$;
select set_config('test.contact',public.contact_group_member(current_setting('test.group')::uuid,'00000000-0000-4000-8000-00000000000a')::text,true);
insert into public.messages(chat_id,sender_id,body) values(current_setting('test.contact')::uuid,auth.uid(),'Hello from the group');
do $$begin
 begin insert into public.messages(chat_id,sender_id,body) values(current_setting('test.contact')::uuid,auth.uid(),'Second text'); raise exception 'pending second send'; exception when raise_exception then if sqlerrm<>'request_pending' then raise; end if; end;
 begin perform public.accept_member_request(current_setting('test.contact')::uuid); raise exception 'sender accepted own request'; exception when insufficient_privilege then null; end;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
insert into public.message_reads(message_id,chat_id,user_id,receipt_visible)
 select id,chat_id,auth.uid(),true from public.messages where chat_id=current_setting('test.contact')::uuid;
do $$begin
 if exists(select 1 from public.message_reads where chat_id=current_setting('test.contact')::uuid) then raise exception 'preview leaked receipt'; end if;
 begin insert into public.messages(chat_id,sender_id,body) values(current_setting('test.contact')::uuid,auth.uid(),'Unaccepted reply'); raise exception 'pending recipient sent'; exception when raise_exception then if sqlerrm<>'request_pending' then raise; end if; end;
end$$;
select public.accept_member_request(current_setting('test.contact')::uuid);
select public.accept_member_request(current_setting('test.contact')::uuid);
insert into public.messages(chat_id,sender_id,body) values(current_setting('test.contact')::uuid,auth.uid(),'Accepted reply');
select public.transfer_group_owner(current_setting('test.group')::uuid,'00000000-0000-4000-8000-00000000000b');
do $$begin
 begin perform public.rename_group(current_setting('test.group')::uuid,'Old owner'); raise exception 'stale owner authority'; exception when insufficient_privilege then null; end;
end$$;
rollback;
