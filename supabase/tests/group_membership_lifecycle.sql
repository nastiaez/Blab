-- Rollback-only proof of approved membership/history/AI contracts.
begin;
update public.app_distribution_policy set channel='public',testing_enabled=true;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
select set_config('test.group',(select chat_id::text from public.create_group('Lifecycle proof')),true);
select set_config('test.token',(select token from public.create_group_invite(current_setting('test.group')::uuid)),true);
insert into public.messages(chat_id,sender_id,body) select current_setting('test.group')::uuid,auth.uid(),'Older original '||n from generate_series(1,499) n;
insert into public.messages(chat_id,sender_id,body) values(current_setting('test.group')::uuid,auth.uid(),'Original before Bob joined') returning set_config('test.old',id::text,true);
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
select * from public.join_group(current_setting('test.token'));
select public.set_learning_language(current_setting('test.group')::uuid,'de');
do $$begin
 if not exists(select 1 from public.messages where id=current_setting('test.old')::uuid) then raise exception 'new member missing original'; end if;
 if public.group_ai_eligible(current_setting('test.old')::uuid,auth.uid()) then raise exception 'historical AI eligible'; end if;
 if exists(select 1 from public.resolve_message_learning_era(current_setting('test.old')::uuid,auth.uid())) then raise exception 'historical learning era leaked'; end if;
 if (public.request_message_translation(current_setting('test.old')::uuid)->>'status')<>'forbidden' then raise exception 'history requested provider work'; end if;
 if not exists(select 1 from public.chat_list where chat_id=current_setting('test.group')::uuid and last_body='Original before Bob joined' and last_practice_body is null) then raise exception 'history preview missing'; end if;
 begin update public.chat_members set joined_at='2000-01-01' where chat_id=current_setting('test.group')::uuid and user_id=auth.uid(); raise exception 'epoch mutable'; exception when insufficient_privilege then null; end;
 begin perform public.remove_group_member(current_setting('test.group')::uuid,'00000000-0000-4000-8000-00000000000a'); raise exception 'member removed owner'; exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$begin
 if exists(select 1 from public.message_preparation_jobs where viewer_id='00000000-0000-4000-8000-00000000000b' and chat_id=current_setting('test.group')::uuid) then raise exception 'history preparation queued'; end if;
end $$;
set local role authenticated;
insert into public.messages(chat_id,sender_id,body) values(current_setting('test.group')::uuid,auth.uid(),'Current membership message') returning set_config('test.current',id::text,true);
do $$begin
 if not public.group_ai_eligible(current_setting('test.current')::uuid,auth.uid()) then raise exception 'current message ineligible'; end if;
end $$;
select public.leave_group(current_setting('test.group')::uuid);
select public.leave_group(current_setting('test.group')::uuid);
do $$begin
 if exists(select 1 from public.chat_list where chat_id=current_setting('test.group')::uuid) then raise exception 'departed group in Chats'; end if;
 if exists(select 1 from public.messages where chat_id=current_setting('test.group')::uuid) then raise exception 'departed history readable'; end if;
 if public.group_ai_eligible(current_setting('test.current')::uuid,auth.uid()) then raise exception 'departed AI eligible'; end if;
end $$;
select * from public.join_group(current_setting('test.token'));
do $$begin
 if (select count(*) from public.messages where chat_id=current_setting('test.group')::uuid and message_type='text')<>501 then raise exception 'rejoin lost originals'; end if;
 if public.group_ai_eligible(current_setting('test.current')::uuid,auth.uid()) then raise exception 'rejoin revived earlier translation'; end if;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
do $$begin
 begin perform public.leave_group(current_setting('test.group')::uuid); raise exception 'owner stranded group'; exception when raise_exception then if sqlerrm<>'owner_transfer_required' then raise; end if; end;
end $$;
select public.remove_group_member(current_setting('test.group')::uuid,'00000000-0000-4000-8000-00000000000b');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
do $$begin
 begin perform public.join_group(current_setting('test.token')); raise exception 'removed member reused link'; exception when raise_exception then if sqlerrm<>'fresh_group_invitation_required' then raise; end if; end;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
select set_config('test.token',(select token from public.replace_group_invite(current_setting('test.group')::uuid)),true);
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
select * from public.join_group(current_setting('test.token'));
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
select public.transfer_group_owner(current_setting('test.group')::uuid,'00000000-0000-4000-8000-00000000000b');
select public.leave_group(current_setting('test.group')::uuid);
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
select public.leave_group(current_setting('test.group')::uuid);
do $$begin
 begin perform public.join_group(current_setting('test.token')); raise exception 'closed group rejoined'; exception when raise_exception then if sqlerrm<>'group_invite_unavailable' then raise; end if; end;
end $$;
rollback;
