-- Disposable database only. Always rolled back; no hosted execution authorized.
begin;
update public.app_distribution_policy set channel='public',testing_enabled=true;
select set_config('test.owner',gen_random_uuid()::text,true);
select set_config('test.member',gen_random_uuid()::text,true);
select set_config('test.fresh',gen_random_uuid()::text,true);
insert into auth.users(id,instance_id,aud,role,email,raw_user_meta_data)
 select id,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',id::text||'@retention.blab.test','{"name":"Private real name"}'::jsonb
 from unnest(array[current_setting('test.owner')::uuid,current_setting('test.member')::uuid]) id;
select set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.owner'))::text,true);
set local role authenticated;
select set_config('test.group',(select chat_id::text from public.create_group('Retained group')),true);
select set_config('test.token',(select token from public.create_group_invite(current_setting('test.group')::uuid)),true);
select set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.member'))::text,true);
select * from public.join_group(current_setting('test.token'));
reset role;
select set_config('test.direct',gen_random_uuid()::text,true);
insert into public.chats(id,member_low_id,member_high_id) values(current_setting('test.direct')::uuid,
 least(current_setting('test.owner')::uuid,current_setting('test.member')::uuid),
 greatest(current_setting('test.owner')::uuid,current_setting('test.member')::uuid));
insert into public.chat_members(chat_id,user_id,learning_language)
 select current_setting('test.direct')::uuid,id,'de' from unnest(array[current_setting('test.owner')::uuid,current_setting('test.member')::uuid]) id;
insert into public.messages(chat_id,sender_id,body) values
 (current_setting('test.direct')::uuid,current_setting('test.owner')::uuid,'Retained direct original'),
 (current_setting('test.group')::uuid,current_setting('test.owner')::uuid,'Retained group original');
insert into public.push_device_tokens(token,user_id,platform) values(repeat('x',32),current_setting('test.owner')::uuid,'android');
select set_config('test.photo',gen_random_uuid()::text,true);
select set_config('test.inflight',gen_random_uuid()::text,true);
select set_config('test.path',current_setting('test.direct')||'/'||current_setting('test.owner')||'/retained.png',true);
insert into public.messages(id,chat_id,sender_id,body,message_type) values(current_setting('test.photo')::uuid,current_setting('test.direct')::uuid,current_setting('test.owner')::uuid,'','image');
insert into public.message_attachments(message_id,chat_id,storage_path,mime_type,byte_size) values(current_setting('test.photo')::uuid,current_setting('test.direct')::uuid,current_setting('test.path'),'image/png',100);
insert into storage.objects(bucket_id,name,owner,owner_id) values('message-media',current_setting('test.path'),current_setting('test.owner')::uuid,current_setting('test.owner'));
insert into public.stream_private_media_assets(bucket_id,object_path,actor_id,chat_id,message_id,upload_lease,status,lease_token,locked_at)
 values('message-media',current_setting('test.path'),current_setting('test.owner')::uuid,current_setting('test.direct')::uuid,current_setting('test.photo')::uuid,gen_random_uuid(),'processing',gen_random_uuid(),now());
-- The processing command belongs to an active Stream-authoritative chat.
insert into public.chat_message_transports(chat_id,provider,migration_state)
 values(current_setting('test.direct')::uuid,'stream','active');
insert into public.stream_message_commands(request_id,chat_id,actor_id,message_id,action,payload_hash,status,lease_token,locked_at)
 values(gen_random_uuid(),current_setting('test.direct')::uuid,current_setting('test.member')::uuid,current_setting('test.inflight')::uuid,'send',repeat('a',64),'processing',gen_random_uuid(),now());
select set_config('request.jwt.claims','{"role":"service_role"}',true);
do $$begin
 if exists(select 1 from public.queue_account_private_media_cleanup(current_setting('test.owner')::uuid) where object_path=current_setting('test.path')) then raise exception 'retained media scheduled for deletion'; end if;
end$$;
delete from auth.users where id=current_setting('test.owner')::uuid;
do $$begin
 if not exists(select 1 from profiles where id=current_setting('test.owner')::uuid and account_deleted_at is not null and display_name='Deleted account' and avatar_path is null and known_languages='{}') then raise exception 'profile not minimized'; end if;
 if public.is_account_active(current_setting('test.owner')::uuid) then raise exception 'deleted auth remains active'; end if;
 if exists(select 1 from push_device_tokens where user_id=current_setting('test.owner')::uuid) then raise exception 'private token retained'; end if;
 if (select count(*) from messages where sender_id=current_setting('test.owner')::uuid and body like 'Retained % original')<>2 then raise exception 'recipient originals lost'; end if;
 if not exists(select 1 from chats where id=current_setting('test.group')::uuid and owner_id=current_setting('test.member')::uuid) then raise exception 'handover lost'; end if;
 if not exists(select 1 from public.stream_account_send_fences where message_id=current_setting('test.inflight')::uuid and actor_id=current_setting('test.member')::uuid) then raise exception 'in-flight send lost durable recovery'; end if;
 if not exists(select 1 from storage.objects where name=current_setting('test.path') and owner is null and owner_id is null) then raise exception 'retained media still auth owned'; end if;
 if not exists(select 1 from public.stream_private_media_assets where object_path=current_setting('test.path') and status='ready' and lease_token is null) then raise exception 'legacy destructive media lease not cancelled'; end if;
 if public.direct_chat_accepts_writes(current_setting('test.direct')::uuid) then raise exception 'deleted direct writable'; end if;
 begin
  insert into messages(chat_id,sender_id,body,created_at) values(current_setting('test.direct')::uuid,current_setting('test.member')::uuid,'Must fail',clock_timestamp());
  raise exception 'deleted direct accepted send';
 exception when raise_exception then
  if SQLERRM<>'account_deleted' then raise; end if;
 end;
end$$;
select set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.owner'))::text,true);
set local role authenticated;
do $$begin
 if exists(select 1 from public.messages where chat_id=current_setting('test.direct')::uuid) then raise exception 'stale deleted JWT retained message access'; end if;
 if exists(select 1 from public.profiles where id=current_setting('test.owner')::uuid) then raise exception 'stale deleted JWT retained profile access'; end if;
 if public.is_chat_member(current_setting('test.direct')::uuid) then raise exception 'stale deleted JWT passed membership helper'; end if;
end$$;
reset role;
select set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.member'))::text,true);
set local role authenticated;
do $$begin
 if (select count(*) from public.group_members(current_setting('test.group')::uuid))<>1 then raise exception 'deleted identity in roster'; end if;
 if not exists(select 1 from public.messages where chat_id=current_setting('test.direct')::uuid and body='Retained direct original') then raise exception 'recipient denied original'; end if;
 if not exists(select 1 from storage.objects where name=current_setting('test.path')) then raise exception 'recipient denied retained media'; end if;
end$$;
reset role;
insert into auth.users(id,instance_id,aud,role,email,raw_user_meta_data) values(current_setting('test.fresh')::uuid,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',current_setting('test.owner')||'@retention.blab.test','{"name":"Fresh identity"}');
do $$begin
 if exists(select 1 from chat_members where user_id=current_setting('test.fresh')::uuid) then raise exception 'signup restored memberships'; end if;
 if exists(select 1 from chats where owner_id=current_setting('test.fresh')::uuid) then raise exception 'signup restored ownership'; end if;
end$$;
rollback;
