begin;
update public.app_distribution_policy set channel='public',testing_enabled=true;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
select set_config('test.group',(select chat_id::text from public.create_group('Conversation QA')),true);
select set_config('test.token',(select token from public.create_group_invite(current_setting('test.group')::uuid)),true);
insert into public.messages(chat_id,sender_id,body) values(current_setting('test.group')::uuid,auth.uid(),'Before Bob joined');
select set_config('test.old_message',(select id::text from public.messages where chat_id=current_setting('test.group')::uuid and body='Before Bob joined'),true);
-- clock_timestamp rather than transaction start proves the history fence.
reset role;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
set local role authenticated;
select * from public.join_group(current_setting('test.token'));
do $$begin
 if not exists(select 1 from public.messages where id=current_setting('test.old_message')::uuid) then raise exception 'original history missing'; end if;
 if public.group_ai_eligible(current_setting('test.old_message')::uuid,auth.uid()) then raise exception 'prejoin AI eligible'; end if;
end$$;
insert into public.messages(chat_id,sender_id,body)
values(current_setting('test.group')::uuid,auth.uid(),'Two-member group');
do $$begin
 if exists(select 1 from public.messages where chat_id=current_setting('test.group')::uuid
 and body='Two-member group' and languages_matched_at_send) then raise exception 'two-member group shared corrections'; end if;
 if public.group_shared_learning_visible(current_setting('test.old_message')::uuid) is distinct from false then raise exception 'prejoin learning metadata leaked'; end if;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000c"}',true);
select * from public.join_group(current_setting('test.token'));
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
insert into public.blocks(blocker_id,blocked_id) values(auth.uid(),'00000000-0000-4000-8000-00000000000b') on conflict do nothing;
insert into public.messages(chat_id,sender_id,body) values(current_setting('test.group')::uuid,auth.uid(),'After both joined');
select set_config('test.message',(select id::text from public.messages where chat_id=current_setting('test.group')::uuid and body='After both joined'),true);
do $$begin
 if not public.group_shared_learning_visible(current_setting('test.message')::uuid) then raise exception 'author lost own shared learning'; end if;
 if (select languages_matched_at_send from public.messages where id=current_setting('test.message')::uuid) then raise exception 'group shared author corrections'; end if;
 if exists(select 1 from public.group_messages_read_by_everyone(current_setting('test.group')::uuid)) then raise exception 'unread message marked read'; end if;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
do $$begin
 if public.group_shared_learning_visible(current_setting('test.message')::uuid) is distinct from false then raise exception 'recipient saw author shared learning'; end if;
end$$;
insert into public.messages(chat_id,sender_id,body) values(current_setting('test.group')::uuid,auth.uid(),'Blocked privately but allowed in group');
insert into public.message_reads(message_id,chat_id,user_id,receipt_visible) values(current_setting('test.message')::uuid,current_setting('test.group')::uuid,auth.uid(),true);
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
do $$begin
 if exists(select 1 from public.group_messages_read_by_everyone(current_setting('test.group')::uuid)) then raise exception 'one reader marked everyone read'; end if;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000c"}',true);
insert into public.message_reads(message_id,chat_id,user_id,receipt_visible) values(current_setting('test.message')::uuid,current_setting('test.group')::uuid,auth.uid(),true);
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
do $$begin
 if not exists(select 1 from public.group_messages_read_by_everyone(current_setting('test.group')::uuid) where message_id=current_setting('test.message')::uuid) then raise exception 'all readers not reflected'; end if;
 begin perform public.leave_chat(current_setting('test.group')::uuid); raise exception 'pair leave closed group'; exception when raise_exception then if sqlerrm<>'use_group_leave_flow' then raise; end if; end;
end$$;
rollback;
