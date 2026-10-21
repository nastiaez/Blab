-- Disposable local QA identities only. Run against Blab_Groups_20261019.
begin;
insert into auth.users(instance_id,id,aud,role,email,encrypted_password,
 email_confirmed_at,confirmation_token,recovery_token,email_change_token_new,
 email_change,email_change_token_current,reauthentication_token,phone_change,
 phone_change_token,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select '00000000-0000-0000-0000-000000000000',v.id,'authenticated','authenticated',
 v.email,extensions.crypt('Blab-local-123!',extensions.gen_salt('bf')),now(),
 '','','','','','','','', '{"provider":"email","providers":["email"]}'::jsonb,
 jsonb_build_object('name',v.name),now(),now()
from (values
 ('b1ab0014-2026-4000-8000-00000000000d'::uuid,'dana.groupqa@blab.test','Dana Local'),
 ('b1ab0014-2026-4000-8000-00000000000e'::uuid,'eve.groupqa@blab.test','Eve Local')
)v(id,email,name) on conflict(id) do nothing;
insert into auth.identities(id,provider_id,user_id,identity_data,provider,created_at,updated_at)
select extensions.gen_random_uuid(),u.id::text,u.id,
 jsonb_build_object('sub',u.id::text,'email',u.email,'email_verified',true),
 'email',now(),now() from auth.users u where u.id in (
 'b1ab0014-2026-4000-8000-00000000000d','b1ab0014-2026-4000-8000-00000000000e')
on conflict(provider_id,provider) do nothing;
insert into public.test_app_members(user_id) values
 ('b1ab0014-2026-4000-8000-00000000000d'),('b1ab0014-2026-4000-8000-00000000000e')
on conflict(user_id) do nothing;
delete from public.chats where chat_kind='direct' and (
 member_low_id in ('b1ab0014-2026-4000-8000-00000000000d','b1ab0014-2026-4000-8000-00000000000e')
 or member_high_id in ('b1ab0014-2026-4000-8000-00000000000d','b1ab0014-2026-4000-8000-00000000000e'));
delete from public.blocks where blocker_id in (
 'b1ab0014-2026-4000-8000-00000000000d','b1ab0014-2026-4000-8000-00000000000e')
 or blocked_id in ('b1ab0014-2026-4000-8000-00000000000d','b1ab0014-2026-4000-8000-00000000000e');
commit;
