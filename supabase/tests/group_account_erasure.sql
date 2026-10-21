begin;
update public.app_distribution_policy set channel='public',testing_enabled=true;
select set_config('test.owner',gen_random_uuid()::text,true);
select set_config('test.member',gen_random_uuid()::text,true);
insert into auth.users(id,instance_id,aud,role,email,raw_user_meta_data)
 select id,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',id::text||'@group-erasure.blab.test','{"name":"Erasure fixture"}'::jsonb
 from unnest(array[current_setting('test.owner')::uuid,current_setting('test.member')::uuid]) id;
select set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.owner'))::text,true);
set local role authenticated;
select set_config('test.group',(select chat_id::text from public.create_group('Shared erasure proof')),true);
select set_config('test.token',(select token from public.create_group_invite(current_setting('test.group')::uuid)),true);
select set_config('test.sole',(select chat_id::text from public.create_group('Sole erasure proof')),true);
select set_config('request.jwt.claims',jsonb_build_object('role','authenticated','sub',current_setting('test.member'))::text,true);
select * from public.join_group(current_setting('test.token'));
insert into public.messages(chat_id,sender_id,body) values(current_setting('test.group')::uuid,auth.uid(),'Remaining member original');
reset role;
delete from auth.users where id=current_setting('test.owner')::uuid;
do $$begin
 if not exists(select 1 from public.chats where id=current_setting('test.group')::uuid and owner_id=current_setting('test.member')::uuid and left_at is null) then raise exception 'account erasure stranded remaining member'; end if;
 if exists(select 1 from public.chats where id=current_setting('test.sole')::uuid) then raise exception 'sole owner erasure retained inaccessible group'; end if;
 if not exists(select 1 from public.messages where chat_id=current_setting('test.group')::uuid and body='Remaining member original') then raise exception 'another members message deleted'; end if;
end $$;
delete from auth.users where id=current_setting('test.member')::uuid;
do $$begin
 if exists(select 1 from public.chats where id=current_setting('test.group')::uuid) then raise exception 'last-account erasure retained inaccessible group'; end if;
end $$;
rollback;
