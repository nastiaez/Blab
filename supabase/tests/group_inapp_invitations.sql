begin;
update public.app_distribution_policy set channel='public',testing_enabled=true;
insert into public.chats(member_low_id,member_high_id) values('00000000-0000-4000-8000-00000000000a','00000000-0000-4000-8000-00000000000b') returning set_config('test.direct',id::text,true);
insert into public.chat_members(chat_id,user_id,learning_language) values(current_setting('test.direct')::uuid,'00000000-0000-4000-8000-00000000000a','de'),(current_setting('test.direct')::uuid,'00000000-0000-4000-8000-00000000000b','en');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
select set_config('test.group',(select chat_id::text from public.create_group('Weekend')),true);
do $$begin
 if (select count(*) from public.group_invite_friends(current_setting('test.group')::uuid))<>1 then raise exception 'wrong eligible friends'; end if;
 begin perform public.send_group_invitations(current_setting('test.group')::uuid,array['00000000-0000-4000-8000-00000000000c'::uuid]); raise exception 'stranger invited'; exception when insufficient_privilege then null; end;
 perform public.send_group_invitations(current_setting('test.group')::uuid,array['00000000-0000-4000-8000-00000000000b'::uuid]);
 perform public.send_group_invitations(current_setting('test.group')::uuid,array['00000000-0000-4000-8000-00000000000b'::uuid,'00000000-0000-4000-8000-00000000000b'::uuid]);
 if exists(select 1 from public.pending_group_invitations) then raise exception 'sender read receiver private inbox'; end if;
 if exists(select 1 from public.group_invitation_inboxes) then raise exception 'sender read receiver inbox revision'; end if;
 if (select count(*) from public.chat_members where chat_id=current_setting('test.group')::uuid)<>1 then raise exception 'invitation autojoined'; end if;
end$$;
-- A block in either direction excludes the recipient and server rejects forging it.
reset role;
insert into public.blocks(blocker_id,blocked_id) values('00000000-0000-4000-8000-00000000000b','00000000-0000-4000-8000-00000000000a');
set local role authenticated;
do $$begin
 if exists(select 1 from public.group_invite_friends(current_setting('test.group')::uuid)) then raise exception 'blocked friend discoverable'; end if;
 begin perform public.send_group_invitations(current_setting('test.group')::uuid,array['00000000-0000-4000-8000-00000000000b'::uuid]); raise exception 'blocked friend invited'; exception when insufficient_privilege then null; end;
end$$;
reset role;
delete from public.blocks where blocker_id='00000000-0000-4000-8000-00000000000b' and blocked_id='00000000-0000-4000-8000-00000000000a';
set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
select set_config('test.oldtoken',(select token from public.list_pending_group_invitations()),true);
select public.view_group_invitation(current_setting('test.oldtoken'));
do $$begin
 if (select count(*) from public.list_pending_group_invitations())<>1 then raise exception 'invite not idempotent'; end if;
 if exists(select 1 from public.messages where chat_id=current_setting('test.group')::uuid) then raise exception 'invite leaked group history'; end if;
 begin perform public.send_group_invitations(current_setting('test.group')::uuid,array['00000000-0000-4000-8000-00000000000a'::uuid]); raise exception 'outsider invited'; exception when insufficient_privilege then null; end;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
select public.send_group_invitations(current_setting('test.group')::uuid,array['00000000-0000-4000-8000-00000000000b'::uuid]);
select * from public.replace_group_invite(current_setting('test.group')::uuid);
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
do $$declare t text; begin
 select token into t from public.list_pending_group_invitations();
 if t=current_setting('test.oldtoken') then raise exception 'named invite still old link'; end if;
 if (select viewed_at from public.list_pending_group_invitations()) is null then raise exception 'resend reset unread'; end if;
 perform public.join_group(t);
 if exists(select 1 from public.list_pending_group_invitations()) then raise exception 'accepted invitation retained'; end if;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
do $$begin
 if exists(select 1 from public.group_invite_friends(current_setting('test.group')::uuid)) then raise exception 'member in friend picker'; end if;
end$$;
-- Removed member cannot revive the old link, even by registering it themselves.
select set_config('test.currenttoken',(select token from public.create_group_invite(current_setting('test.group')::uuid)),true);
select public.remove_group_member(current_setting('test.group')::uuid,'00000000-0000-4000-8000-00000000000b');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);

select public.register_group_invitation(current_setting('test.currenttoken'));
do $$begin
 begin perform public.join_group(current_setting('test.currenttoken')); raise exception 'old link revived after removal'; exception when raise_exception then if sqlerrm<>'fresh_group_invitation_required' then raise; end if; end;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
select public.send_group_invitations(current_setting('test.group')::uuid,array['00000000-0000-4000-8000-00000000000b'::uuid]);
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
select * from public.join_group(current_setting('test.currenttoken'));
reset role;
do $$begin
 if exists(select 1 from public.message_preparation_jobs where chat_id=current_setting('test.group')::uuid) then raise exception 'invite queued AI'; end if;
end$$;
-- A pending invitation cannot prevent the inviter from erasing their account.
insert into public.chats(member_low_id,member_high_id) values('00000000-0000-4000-8000-00000000000a','00000000-0000-4000-8000-00000000000c') returning set_config('test.direct2',id::text,true);
insert into public.chat_members(chat_id,user_id,learning_language) values(current_setting('test.direct2')::uuid,'00000000-0000-4000-8000-00000000000a','de'),(current_setting('test.direct2')::uuid,'00000000-0000-4000-8000-00000000000c','en');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
select public.send_group_invitations(current_setting('test.group')::uuid,array['00000000-0000-4000-8000-00000000000c'::uuid]);
reset role;
delete from auth.users where id='00000000-0000-4000-8000-00000000000a';
do $$begin
 if not exists(select 1 from public.chats where id=current_setting('test.group')::uuid and owner_id='00000000-0000-4000-8000-00000000000b') then raise exception 'pending invite blocked erasure/transfer'; end if;
end$$;
rollback;
