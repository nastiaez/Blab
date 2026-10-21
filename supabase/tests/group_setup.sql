-- Local seeded accounts; rollback-only group setup/authorization regression.
begin;
update public.app_distribution_policy set channel='public',testing_enabled=true;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
select set_config('test.group',(select chat_id::text from public.create_group('Weekend')),true);
select set_config('test.group_invite',(select token from public.create_group_invite(current_setting('test.group')::uuid)),true);
do $$begin
 if (select token from public.create_group_invite(current_setting('test.group')::uuid)) <> current_setting('test.group_invite') then raise exception 'share rotated invitation'; end if;
 if (select member_count from public.get_group_invite(current_setting('test.group_invite'))) <> 1 then raise exception 'creator missing from count'; end if;
 begin perform public.create_group('  '); raise exception 'empty name accepted'; exception when raise_exception then if sqlerrm <> 'invalid_group_name' then raise; end if; end;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
select public.register_group_invitation(current_setting('test.group_invite'));
select public.register_group_invitation(current_setting('test.group_invite'));
do $$begin
 if (select count(*) from public.list_pending_group_invitations())<>1 then raise exception 'pending invite not idempotent'; end if;
 if public.is_chat_member(current_setting('test.group')::uuid) then raise exception 'opening invite joined group'; end if;
 if (select viewed_at from public.list_pending_group_invitations()) is not null then raise exception 'new invite not unread'; end if;
end$$;
select public.view_group_invitation(current_setting('test.group_invite'));
select public.register_group_invitation(current_setting('test.group_invite'));
do $$begin
 if (select viewed_at from public.list_pending_group_invitations()) is null then raise exception 'preview did not clear local unread'; end if;
 if public.is_chat_member(current_setting('test.group')::uuid) then raise exception 'preview joined group'; end if;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000c"}',true);
select public.reject_group_invitation(current_setting('test.group_invite'));
do $$begin
 if exists(select 1 from public.list_pending_group_invitations()) then raise exception 'other account saw invite'; end if;
end$$;
select public.register_group_invitation(current_setting('test.group_invite'));
select public.reject_group_invitation(current_setting('test.group_invite'));
do $$begin
 if exists(select 1 from public.list_pending_group_invitations()) then raise exception 'reject retained invite'; end if;
 if public.is_chat_member(current_setting('test.group')::uuid) then raise exception 'reject created membership'; end if;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
do $$begin
 if (select count(*) from public.list_pending_group_invitations())<>1 then raise exception 'other account rejected my invite'; end if;
end$$;
do $$begin
 begin perform public.create_group_invite(current_setting('test.group')::uuid); raise exception 'outsider shared'; exception when insufficient_privilege then null; end;
end$$;
select * from public.join_group(current_setting('test.group_invite'));
do $$begin
 if exists(select 1 from public.list_pending_group_invitations()) then raise exception 'join retained pending row'; end if;
 if not (select already_member from public.join_group(current_setting('test.group_invite'))) then raise exception 'duplicate join not recognized'; end if;
 if (select count(*) from public.chat_members where chat_id=current_setting('test.group')::uuid)<>2 then raise exception 'duplicate membership'; end if;
 begin perform public.replace_group_invite(current_setting('test.group')::uuid); raise exception 'member rotated owner link'; exception when insufficient_privilege then null; end;
 if not exists(select 1 from public.chat_list where chat_id=current_setting('test.group')::uuid and chat_kind='group' and partner_name='Weekend') then raise exception 'group absent from chat list'; end if;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
select set_config('test.new_invite',(select token from public.replace_group_invite(current_setting('test.group')::uuid)),true);
do $$begin
 if current_setting('test.new_invite')=current_setting('test.group_invite') then raise exception 'rotation retained token'; end if;
 if (select status from public.get_group_invite(current_setting('test.group_invite'))) <> 'unavailable' then raise exception 'old invite still valid'; end if;
 if (select member_count from public.get_group_invite(current_setting('test.new_invite'))) <> 2 then raise exception 'rotation removed members'; end if;
end$$;
rollback;
