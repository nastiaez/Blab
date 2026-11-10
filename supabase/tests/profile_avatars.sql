-- BLA39 real PostgreSQL policy/RPC regression; disposable database only.
\set ON_ERROR_STOP on
begin;
insert into public.app_distribution_policy(singleton,channel) values(true,'public')
on conflict (singleton) do update set channel=excluded.channel;
insert into auth.users(id,instance_id,aud,role,email,raw_app_meta_data,raw_user_meta_data)
select ('39000000-0000-4000-8000-00000000000'||n)::uuid,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',n||'@avatar.blab.test','{"provider":"google"}','{"name":"Avatar QA","avatar_url":"https://lh3.googleusercontent.com/initial"}' from unnest(array['a','b','c']) n;
create function pg_temp.assert_true(ok boolean,label text) returns void language plpgsql as $$begin if ok is distinct from true then raise exception 'FAIL %',label;end if;raise notice 'PASS %',label;end$$;
select pg_temp.assert_true((select count(*)=3 from profiles where avatar_path='https://lh3.googleusercontent.com/initial'),'new Google init');
insert into chats(id,member_low_id,member_high_id) values('10000000-0000-4000-8000-000000000000','39000000-0000-4000-8000-00000000000a','39000000-0000-4000-8000-00000000000b');
insert into chat_members(chat_id,user_id,learning_language) select '10000000-0000-4000-8000-000000000000',('39000000-0000-4000-8000-00000000000'||n)::uuid,'en' from unnest(array['a','b']) n;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"39000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
insert into storage.objects(bucket_id,name,owner,metadata) values('profile-avatars','39000000-0000-4000-8000-00000000000a/10000000-0000-4000-8000-000000000001.jpg',auth.uid(),'{"mimetype":"image/jpeg"}');
select pg_temp.assert_true((select count(*)=1 from storage.objects where bucket_id='profile-avatars'),'owner upload/read');
do $$begin
begin insert into storage.objects(bucket_id,name) values('profile-avatars','39000000-0000-4000-8000-00000000000b/10000000-0000-4000-8000-000000000002.jpg');raise exception 'cross upload accepted';exception when insufficient_privilege then raise notice 'PASS cross upload denied';end;
begin perform update_my_avatar(null,'39000000-0000-4000-8000-00000000000b');raise exception 'wrong actor accepted';exception when insufficient_privilege then raise notice 'PASS expected actor removal denied';end;
end$$;
select update_my_avatar('39000000-0000-4000-8000-00000000000a/10000000-0000-4000-8000-000000000001.jpg',auth.uid());
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
update profile_avatar_cleanup set next_attempt_at=now()-interval '1 second';
select pg_temp.assert_true((select count(*)=0 from claim_profile_avatar_cleanup()),'current avatar excluded from cleanup');
update profile_avatar_cleanup set next_attempt_at=now()+interval '15 minutes';
select set_config('request.jwt.claims','{"role":"authenticated","sub":"39000000-0000-4000-8000-00000000000b"}',true);
set local role authenticated;
select pg_temp.assert_true((select count(*)=1 from storage.objects where bucket_id='profile-avatars'),'authorized peer current read');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"39000000-0000-4000-8000-00000000000c"}',true);
select pg_temp.assert_true((select count(*)=0 from storage.objects where bucket_id='profile-avatars'),'outsider read denied');
reset role;
update auth.users set raw_user_meta_data='{"avatar_url":"https://lh3.googleusercontent.com/changed"}' where id='39000000-0000-4000-8000-00000000000a';
select pg_temp.assert_true((select avatar_path like '%0001.jpg' from profiles where id='39000000-0000-4000-8000-00000000000a'),'returning metadata preserves custom');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"39000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
select update_my_avatar(null,auth.uid());
reset role;
update auth.users set last_sign_in_at=now(),raw_user_meta_data='{"avatar_url":"https://lh3.googleusercontent.com/again"}' where id='39000000-0000-4000-8000-00000000000a';
select pg_temp.assert_true((select avatar_path is null from profiles where id='39000000-0000-4000-8000-00000000000a'),'returning metadata preserves removal');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"39000000-0000-4000-8000-00000000000b"}',true);
set local role authenticated;
select pg_temp.assert_true((select count(*)=0 from storage.objects where bucket_id='profile-avatars'),'peer cannot read removed object');
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select pg_temp.assert_true((select count(*)=0 from claim_profile_avatar_cleanup()),'cleanup grace');
update profile_avatar_cleanup set next_attempt_at=now()-interval '1 second';
select pg_temp.assert_true((select count(*)=1 from claim_profile_avatar_cleanup()),'orphan claim');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"39000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
do $$begin begin perform update_my_avatar('39000000-0000-4000-8000-00000000000a/10000000-0000-4000-8000-000000000001.jpg',auth.uid());raise exception 'claimed upload committed';exception when raise_exception then if sqlerrm<>'avatar_upload_expired' then raise;end if;raise notice 'PASS claimed object commit rejected';end;end$$;
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select pg_temp.assert_true(not finish_profile_avatar_cleanup('39000000-0000-4000-8000-00000000000a/10000000-0000-4000-8000-000000000001.jpg',gen_random_uuid(),true),'wrong lease denied');
select queue_profile_avatar_account_erasure('39000000-0000-4000-8000-00000000000a');
select pg_temp.assert_true((select owner is null and owner_id is null from storage.objects where bucket_id='profile-avatars'),'erasure clears owner');
delete from auth.users where id='39000000-0000-4000-8000-00000000000a';
select pg_temp.assert_true((select count(*)=1 from profile_avatar_cleanup),'cleanup survives auth erasure');
rollback;
