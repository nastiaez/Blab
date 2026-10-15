-- Disposable database only. Never changes hosted accounts.
begin;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
-- Public behavior is retained without membership registration.
do $$ declare t text; begin
  select token into t from public.create_invite();
  if t like 'test-%' then raise exception 'public token tagged test'; end if;
  if not public.is_account_active(auth.uid()) then raise exception 'public blocked'; end if;
end $$;
update public.app_distribution_policy set channel='test',testing_enabled=true;
insert into public.test_app_members(user_id) values
 ('00000000-0000-4000-8000-00000000000a'),
 ('00000000-0000-4000-8000-00000000000b');
set local role authenticated;
do $$ declare t text; begin
  select token into t from public.create_invite();
  if t not like 'test-%' then raise exception 'test token missing prefix'; end if;
  perform set_config('blab.test_invite',t,true);
  begin
    perform public.claim_invite('public-token');
    raise exception 'cross channel accepted';
  exception when raise_exception then
    if sqlerrm <> 'invite_channel_mismatch' then raise; end if;
  end;
  begin
    update public.app_distribution_policy set testing_enabled=false;
    raise exception 'client changed policy';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.test_app_members(user_id) values ('00000000-0000-4000-8000-00000000000c');
    raise exception 'client self enrolled';
  exception when insufficient_privilege then null; end;
  begin
    perform public.claim_invite_in_namespace('public-token');
    raise exception 'client bypassed wrapper';
  exception when insufficient_privilege then null; end;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000c"}',true);
do $$ begin
  begin
    perform public.claim_invite(current_setting('blab.test_invite'));
    raise exception 'unapproved claimed';
  exception when raise_exception then
    if sqlerrm <> 'account_suspended' then raise; end if;
  end;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
do $$ declare c uuid; begin
  select chat_id into c from public.claim_invite(current_setting('blab.test_invite'));
  perform set_config('blab.test_chat',c::text,true);
  insert into public.messages(chat_id,sender_id,body) values(c,auth.uid(),'Test message');
  if not exists(select 1 from public.messages where chat_id=c) then raise exception 'approved cannot read'; end if;
end $$;
reset role;
update public.app_distribution_policy set testing_enabled=false;
set local role authenticated;
do $$ begin
  if public.get_app_distribution_access()->>'status' <> 'ended' then raise exception 'not ended'; end if;
  if exists(select 1 from public.messages where chat_id=current_setting('blab.test_chat')::uuid) then raise exception 'revoked read'; end if;
  begin
    insert into public.messages(chat_id,sender_id,body) values(current_setting('blab.test_chat')::uuid,auth.uid(),'Blocked');
    raise exception 'revoked send';
  exception when insufficient_privilege then null; end;
  begin
    perform public.create_invite();
    raise exception 'revoked invite';
  exception when raise_exception then
    if sqlerrm <> 'account_suspended' then raise; end if;
  end;
end $$;
reset role;
update public.app_distribution_policy set testing_enabled=true;
update public.test_app_members set expires_at=now()-interval '1 second' where user_id='00000000-0000-4000-8000-00000000000b';
do $$ begin
  if public.is_account_active('00000000-0000-4000-8000-00000000000b') then raise exception 'expired member active'; end if;
  if not public.is_account_active('00000000-0000-4000-8000-00000000000a') then raise exception 'unrelated member blocked'; end if;
end $$;
update public.app_distribution_policy set channel='public';
do $$ begin
  if not public.is_account_active('00000000-0000-4000-8000-00000000000b') then raise exception 'test expiry affected public'; end if;
  raise notice 'PASS public/test namespace, operator-only policy, approved claims, unapproved denial, kill read/send/invite, individual expiry';
end $$;
rollback;
