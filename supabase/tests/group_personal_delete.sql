-- Delete is viewer-only, never removal, ownership change or global destruction.
begin;
update public.app_distribution_policy set channel='public',testing_enabled=true;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
select set_config('test.group',(select chat_id::text from public.create_group('Personal delete proof')),true);
select set_config('test.token',(select token from public.create_group_invite(current_setting('test.group')::uuid)),true);
insert into public.messages(chat_id,sender_id,body) values(current_setting('test.group')::uuid,auth.uid(),'Original retained for others');
-- Emulate an earlier committed transaction: group inserts stamp wall time,
-- whereas the existing personal-clear RPC uses this transaction's now().
reset role;
set local session_replication_role=replica;
update public.messages set created_at=now()-interval '1 second' where chat_id=current_setting('test.group')::uuid and message_type='text';
set local session_replication_role=origin;
set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
select * from public.join_group(current_setting('test.token'));
select public.delete_chat(current_setting('test.group')::uuid);
do $$begin
 if exists(select 1 from public.chat_list where chat_id=current_setting('test.group')::uuid) then raise exception 'deleted group still in viewer Chats'; end if;
 if exists(select 1 from public.messages where chat_id=current_setting('test.group')::uuid and message_type='text') then raise exception 'personally cleared history still visible'; end if;
 if not public.is_chat_member(current_setting('test.group')::uuid) then raise exception 'personal delete removed membership'; end if;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
do $$begin
 if not exists(select 1 from public.messages where chat_id=current_setting('test.group')::uuid and body='Original retained for others') then raise exception 'personal delete destroyed another members history'; end if;
end $$;
insert into public.messages(chat_id,sender_id,body,created_at) values(current_setting('test.group')::uuid,auth.uid(),'New message restores the group',clock_timestamp());
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
do $$begin
 if not exists(select 1 from public.chat_list where chat_id=current_setting('test.group')::uuid) then raise exception 'new group message did not restore Chats'; end if;
 if exists(select 1 from public.messages where chat_id=current_setting('test.group')::uuid and body='Original retained for others') then raise exception 'new group message revived cleared history'; end if;
 if not exists(select 1 from public.messages where chat_id=current_setting('test.group')::uuid and body='New message restores the group') then raise exception 'new group message unreadable'; end if;
end $$;
-- The owner can personally clear the chat without handing ownership away.
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
select public.delete_chat(current_setting('test.group')::uuid);
reset role;
do $$begin
 if not exists(select 1 from public.chats where id=current_setting('test.group')::uuid and owner_id='00000000-0000-4000-8000-00000000000a' and left_at is null) then raise exception 'owner personal delete closed or transferred group'; end if;
 if (select count(*) from public.chat_members where chat_id=current_setting('test.group')::uuid)<>2 then raise exception 'personal delete changed roster'; end if;
end $$;
rollback;
