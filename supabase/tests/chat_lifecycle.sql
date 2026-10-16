-- Seeded local accounts only. Exercise authority/RLS, not hosted vendor mocks.
begin;
update public.app_distribution_policy set channel='public',testing_enabled=true;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
select set_config('test.invite',(select token from public.create_invite()),true);
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
select set_config('test.chat',(select chat_id::text from public.claim_invite(current_setting('test.invite'))),true);
reset role;
insert into public.messages(chat_id,sender_id,body,created_at) values(current_setting('test.chat')::uuid,'00000000-0000-4000-8000-00000000000a','Before clear',now()-interval '1 minute');
set local role authenticated;
select public.delete_chat(current_setting('test.chat')::uuid);
select public.delete_chat(current_setting('test.chat')::uuid);
do $$begin
 if exists(select 1 from public.chat_list where chat_id=current_setting('test.chat')::uuid) then raise exception 'deleted chat visible'; end if;
 if exists(select 1 from public.messages where chat_id=current_setting('test.chat')::uuid) then raise exception 'cleared history visible'; end if;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
do $$begin
 if not exists(select 1 from public.chat_list where chat_id=current_setting('test.chat')::uuid) then raise exception 'partner list erased'; end if;
 if not exists(select 1 from public.messages where chat_id=current_setting('test.chat')::uuid) then raise exception 'partner history erased'; end if;
end$$;
reset role;
insert into public.messages(chat_id,sender_id,body,created_at) values(current_setting('test.chat')::uuid,'00000000-0000-4000-8000-00000000000a','Delayed old event',now()-interval '30 seconds');
set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
do $$begin
 if exists(select 1 from public.chat_list where chat_id=current_setting('test.chat')::uuid) then raise exception 'old replay restored chat'; end if;
end$$;
reset role;
insert into public.messages(chat_id,sender_id,body,created_at) values(current_setting('test.chat')::uuid,'00000000-0000-4000-8000-00000000000a','New incoming',now()+interval '1 second');
set local role authenticated;
do $$begin
 if not exists(select 1 from public.chat_list where chat_id=current_setting('test.chat')::uuid) then raise exception 'incoming did not restore chat'; end if;
 if (select count(*) from public.messages where chat_id=current_setting('test.chat')::uuid)<>1 then raise exception 'earlier history restored'; end if;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000c"}',true);
do $$begin
 begin perform public.leave_chat(current_setting('test.chat')::uuid); raise exception 'outsider left chat'; exception when insufficient_privilege then null; end;
 begin perform public.delete_chat(current_setting('test.chat')::uuid); raise exception 'outsider deleted chat'; exception when insufficient_privilege then null; end;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
select public.leave_chat(current_setting('test.chat')::uuid);
select public.leave_chat(current_setting('test.chat')::uuid);
do $$begin
 if not exists(select 1 from public.chat_list where chat_id=current_setting('test.chat')::uuid and left_at is not null and unread_count=0) then raise exception 'left state absent'; end if;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
do $$begin
 if not exists(select 1 from public.chat_list where chat_id=current_setting('test.chat')::uuid and left_at is not null) then raise exception 'partner not left'; end if;
end$$;
reset role;
do $$begin
 begin
 insert into public.messages(chat_id,sender_id,body) values(current_setting('test.chat')::uuid,'00000000-0000-4000-8000-00000000000a','Must fail');
 raise exception 'closed chat accepted new send';
 exception when raise_exception then if sqlerrm<>'chat_left' then raise; end if; end;
 if (select count(*) from public.chat_members where chat_id=current_setting('test.chat')::uuid and chat_left_at is not null)<>2 then raise exception 'membership updates missing'; end if;
end$$;
-- Stream reservations cannot bypass the same terminal-chat authority.
insert into public.chat_message_transports(chat_id,provider,migration_state)
values(current_setting('test.chat')::uuid,'stream','active');
set local role authenticated;
do $$begin
 begin perform public.authorize_stream_message_command(gen_random_uuid(),current_setting('test.chat')::uuid,gen_random_uuid(),'send','Forbidden');
 raise exception 'Stream send accepted'; exception when raise_exception then if sqlerrm<>'chat_left' then raise; end if; end;
 begin perform public.reserve_stream_media_upload(current_setting('test.chat')::uuid,gen_random_uuid(),repeat('a',64),repeat('b',64));
 raise exception 'Stream upload accepted'; exception when raise_exception then if sqlerrm<>'chat_left' then raise; end if; end;
 begin update public.chat_members set hidden_at=now() where chat_id=current_setting('test.chat')::uuid and user_id=auth.uid();
 raise exception 'forged lifecycle accepted'; exception when insufficient_privilege then null; end;
end$$;
reset role;
set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
do $$declare fresh uuid; again uuid;begin
 select chat_id into fresh from public.claim_invite(current_setting('test.invite'));
 if fresh::text=current_setting('test.chat') then raise exception 'reinvite reopened old chat'; end if;
 select chat_id into again from public.claim_invite(current_setting('test.invite'));
 if fresh<>again then raise exception 'active pair not deduplicated'; end if;
 if exists(select 1 from public.messages where chat_id=fresh) then raise exception 'new chat has old history'; end if;
 perform public.delete_chat(fresh);
 select chat_id into again from public.claim_invite(current_setting('test.invite'));
 if fresh=again then raise exception 'reinvite after personal delete reused old chat'; end if;
end$$;
rollback;
