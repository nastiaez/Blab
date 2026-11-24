-- Executes against the owned isolated fixture plus actual migration.
select public.test_assert((select practice_language_selected_at is null and learning_language='en' from chat_members where chat_id='00000000-0000-4000-8000-000000000055'),'legacy unset row changed');
select public.test_assert((select payload='historical-result' from message_prepared_packages),'historical package changed');
select public.test_assert((select payload='historical-job' from message_preparation_jobs),'historical job changed');
select public.test_assert(not has_function_privilege('anon','confirm_my_onboarding_languages(integer,text,text)','execute'),'anon can execute');
select public.test_assert(not has_function_privilege('authenticated','apply_new_membership_learning_default()','execute'),'private trigger callable');
select public.test_assert(not has_column_privilege('authenticated','profiles','default_learning_language','update'),'default table-write bypass');
set role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000000a',false);
select confirm_my_onboarding_languages(1,'de','fr');
select public.test_assert((select default_learning_language='de' and primary_known_language='en' and interface_language='uk' and onboarding_stage='complete' from profiles where id=auth.uid()),'own atomic prefs or explicit known/interface changed');
select confirm_my_onboarding_languages(1,'ta','uk');
select public.test_assert((select default_learning_language='de' and primary_known_language='en' from profiles where id=auth.uid()),'replay overwrote saved account preferences');
do $$begin
 begin perform confirm_my_onboarding_languages(1,null,'en');raise exception 'missing learning accepted';exception when check_violation then null;end;
 begin perform confirm_my_onboarding_languages(1,'xx','en');raise exception 'unsupported learning accepted';exception when check_violation then null;end;
 begin perform confirm_my_onboarding_languages(2,'de','en');raise exception 'wrong version accepted';exception when check_violation then null;end;
 begin update profiles set default_learning_language='fr' where id=auth.uid();raise exception 'direct default update accepted';exception when insufficient_privilege then null;end;
end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000000b',false);
select public.test_assert((select default_learning_language is null from profiles where id=auth.uid()),'A changed B preference');
select confirm_my_onboarding_languages(1,'ta','uk');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000000c',false);
do $$begin begin perform confirm_my_onboarding_languages(1,'de','en');raise exception 'legacy completed account silently migrated';exception when check_violation then null;end;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000000d',false);
do $$begin begin perform confirm_my_onboarding_languages(1,'de','en');raise exception 'inactive account accepted';exception when raise_exception then if sqlerrm<>'account_suspended' then raise;end if;end;end$$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000000e',false);
do $$begin begin perform confirm_my_onboarding_languages(1,'de','en');raise exception 'name stage skipped';exception when check_violation then null;end;end$$;
select set_config('request.jwt.claim.sub','',false);
do $$begin begin perform confirm_my_onboarding_languages(1,'de','en');raise exception 'anonymous accepted';exception when raise_exception then if sqlerrm<>'not_authenticated' then raise;end if;end;end$$;
reset role;
-- New DM and group participants are resolved from EACH row's own profile.
insert into chats values('00000000-0000-4000-8000-000000000010','direct'),('00000000-0000-4000-8000-000000000020','group'),('00000000-0000-4000-8000-000000000030','direct');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000000a',false);
insert into chat_members(chat_id,user_id,learning_language,practice_language_selected_at)
select c.id,p.id,'en',null from chats c cross join profiles p where c.id in('00000000-0000-4000-8000-000000000010','00000000-0000-4000-8000-000000000020') and p.id in('00000000-0000-4000-8000-00000000000a','00000000-0000-4000-8000-00000000000b','00000000-0000-4000-8000-00000000000c');
select test_assert((select count(*)=2 from chat_members where user_id='00000000-0000-4000-8000-00000000000a' and learning_language='de' and practice_language_selected_at is not null and mode='normal'),'A default/mode/new chat sheet gate wrong');
select test_assert((select count(*)=2 from chat_members where user_id='00000000-0000-4000-8000-00000000000b' and learning_language='ta' and practice_language_selected_at is not null),'B received inviter default');
select test_assert((select count(*)=3 from chat_members where user_id='00000000-0000-4000-8000-00000000000c' and practice_language_selected_at is null),'legacy no-default fallback changed');
select test_assert(not exists(select 1 from chat_members cm join chat_language_timeline t using(chat_id,user_id) where cm.practice_language_selected_at is not null and (t.learning_language<>cm.learning_language or t.created_at<>cm.joined_at or t.revision<>1)),'initial era wrong');
insert into chat_members(chat_id,user_id,learning_language,practice_language_selected_at) values('00000000-0000-4000-8000-000000000030','00000000-0000-4000-8000-00000000000a','fr',now());
select test_assert((select learning_language='fr' from chat_members where chat_id='00000000-0000-4000-8000-000000000030'),'explicit selection overwritten');
-- No second initialization on conflict/replay; manual change remains independent.
insert into chat_members(chat_id,user_id,learning_language,practice_language_selected_at) values('00000000-0000-4000-8000-000000000030','00000000-0000-4000-8000-00000000000a','en',null) on conflict do nothing;
select test_assert((select learning_language='fr' from chat_members where chat_id='00000000-0000-4000-8000-000000000030'),'conflict overwrote override');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000000a',false);
set role authenticated;
select set_learning_language('00000000-0000-4000-8000-000000000010','fr');
reset role;
select test_assert((select default_learning_language='de' from profiles where id='00000000-0000-4000-8000-00000000000a'),'manual chat change changed global default');
select test_assert((select learning_language='ta' from chat_members where chat_id='00000000-0000-4000-8000-000000000010' and user_id='00000000-0000-4000-8000-00000000000b'),'manual change affected partner');
select test_assert((select count(*)=2 from chat_language_timeline where chat_id='00000000-0000-4000-8000-000000000010' and user_id='00000000-0000-4000-8000-00000000000a'),'manual revision contract changed');
select test_assert((select learning_language='de' from chat_language_timeline where chat_id='00000000-0000-4000-8000-000000000010' and user_id='00000000-0000-4000-8000-00000000000a' and revision=1),'manual change rewrote earlier era');
update profiles set account_deleted_at=now() where id='00000000-0000-4000-8000-00000000000b';
select test_assert((select default_learning_language is null from profiles where id='00000000-0000-4000-8000-00000000000b'),'erasure retained private default');
select test_assert((select payload='historical-result' from message_prepared_packages) and (select payload='historical-job' from message_preparation_jobs),'history/cache/job rewritten');
select 'onboarding learning default SQL contract PASS' as result;
