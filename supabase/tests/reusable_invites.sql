-- Local seeded Alice/Bob/Carol only; rollback all effects.
begin;
update public.app_distribution_policy set channel='public', testing_enabled=true;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
do $$ declare t text; t2 text; begin
 select token into t from public.create_invite();
 select token into t2 from public.create_invite();
 if t<>t2 then raise exception 'create rotated'; end if;
 perform set_config('blab.invite.old',t,true);
 begin
  perform public.claim_invite(t); raise exception 'self accepted';
 exception when raise_exception then if sqlerrm<>'invite_self_claim' then raise; end if; end;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
do $$ declare c uuid; again uuid; begin
 select chat_id into c from public.claim_invite(current_setting('blab.invite.old'));
 select chat_id into again from public.claim_invite(current_setting('blab.invite.old'));
 if c<>again then raise exception 'duplicate pair'; end if;
 perform set_config('blab.invite.chat',c::text,true);
 if not exists(select 1 from public.get_invite(current_setting('blab.invite.old')) where status='valid') then raise exception 'consumed link'; end if;
 begin
  perform public.regenerate_invite(current_setting('blab.invite.old')); raise exception 'nonowner rotated';
 exception when raise_exception then if sqlerrm<>'invite_not_found' then raise; end if; end;
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000c"}',true);
do $$ declare c uuid; begin
 select chat_id into c from public.claim_invite(current_setting('blab.invite.old'));
 if c::text=current_setting('blab.invite.chat') then raise exception 'wrong shared conversation'; end if;
end $$;
reset role;
do $$ begin
 if (select count(*) from public.push_notification_events
     where event_type='invite_claimed' and source_key like current_setting('blab.invite.old') || ':%') <> 2
 then raise exception 'expected exactly one invite event per recipient despite repeated claim'; end if;
end $$;
insert into public.blocks(blocker_id,blocked_id) values
 ('00000000-0000-4000-8000-00000000000a','00000000-0000-4000-8000-00000000000b') on conflict do nothing;
update public.chat_members set learning_language='de' where chat_id=current_setting('blab.invite.chat')::uuid and user_id='00000000-0000-4000-8000-00000000000b';
set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
do $$ declare t text; again text; begin
 select token into t from public.regenerate_invite(current_setting('blab.invite.old'));
 if t=current_setting('blab.invite.old') then raise exception 'rotation unchanged'; end if;
 select token into again from public.regenerate_invite(current_setting('blab.invite.old'));
 if t<>again then raise exception 'lost response retry rotated twice'; end if;
 if exists(select 1 from public.get_invite(current_setting('blab.invite.old'))) then raise exception 'revoked visible'; end if;
 perform set_config('blab.invite.new',t,true);
end $$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
do $$ declare c uuid; begin
 begin
  perform public.claim_invite(current_setting('blab.invite.old')); raise exception 'revoked accepted';
 exception when raise_exception then if sqlerrm<>'invite_not_found' then raise; end if; end;
 select chat_id into c from public.claim_invite(current_setting('blab.invite.new'));
 if c::text<>current_setting('blab.invite.chat') then raise exception 'existing chat lost'; end if;
 if not exists(select 1 from public.chat_members where chat_id=c and user_id=auth.uid()) then raise exception 'existing membership lost'; end if;
end $$;
reset role;
do $$ begin
 if not exists(select 1 from public.blocks where blocker_id='00000000-0000-4000-8000-00000000000a' and blocked_id='00000000-0000-4000-8000-00000000000b') then raise exception 'block cleared'; end if;
 if not exists(select 1 from public.chat_members where chat_id=current_setting('blab.invite.chat')::uuid and user_id='00000000-0000-4000-8000-00000000000b' and learning_language='de') then raise exception 'language reset'; end if;
end $$;
rollback;
