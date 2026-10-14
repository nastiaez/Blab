begin;
select plan(9);
insert into chats(id) values('75000000-0000-4000-8000-000000000001');
insert into chat_members(chat_id,user_id,learning_language,mode) values
('75000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000a','de','normal'),
('75000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000b','en','normal');
update profiles set primary_known_language='en',known_languages=array['en'] where id='00000000-0000-4000-8000-00000000000a';
insert into messages(id,chat_id,sender_id,body,created_at) values('75000000-0000-4000-8000-000000000002','75000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-00000000000b','Tomorrow afternoon',now()+interval '1 second');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}',true);
set local role authenticated;
select is(request_message_translation_variant('75000000-0000-4000-8000-000000000002','de')->>'targetLang','de','visible Practice request does not depend on saved Normal mode');
select is((select mode from chat_members where chat_id='75000000-0000-4000-8000-000000000001' and user_id=auth.uid()),'normal','translation request does not mutate selected mode');
select is(request_message_translation_variant('75000000-0000-4000-8000-000000000002','fr')->>'status','forbidden','arbitrary language cannot forge authorized viewer lane');
update chat_members set mode='practice' where chat_id='75000000-0000-4000-8000-000000000001' and user_id=auth.uid();
select is(request_message_translation_variant('75000000-0000-4000-8000-000000000002','en')->>'targetLang','en','visible Normal request ignores old saved Practice mode');
select is(request_message_translation('75000000-0000-4000-8000-000000000002')->>'targetLang','de','legacy callers retain saved-mode behavior');
select is(request_message_translation_variant('75000000-0000-4000-8000-000000000002','en',true)->>'targetLang','en','forced refresh uses the requested authorized lane');
reset role;
update profiles set known_languages='{}'::text[] where id='00000000-0000-4000-8000-00000000000a';
insert into message_translations(message_id,target_lang,translation_text,tokens,source_lang,source_hash,interface_lang,aid_mode,interface_text,cache_contract_version)
values('75000000-0000-4000-8000-000000000002','de','Morgen Nachmittag','[]'::jsonb,'en',encode(digest(convert_to('Tomorrow afternoon','UTF8'),'sha256'),'hex'),'en','translation','Tomorrow afternoon','minimal-source-anchor-v11');
set local role authenticated;
select is(request_message_translation_variant('75000000-0000-4000-8000-000000000002','en')->>'status','no_aid_needed','primary known language remains known for legacy empty language lists');
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000000c","role":"authenticated"}',true);
set local role authenticated;
select is(request_message_translation_variant('75000000-0000-4000-8000-000000000002','de')->>'status','forbidden','nonmember cannot request private translation');
reset role;
update messages set deleted_at=now() where id='75000000-0000-4000-8000-000000000002';
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}',true);
set local role authenticated;
select is(request_message_translation_variant('75000000-0000-4000-8000-000000000002','de')->>'status','forbidden','deleted source cannot be translated');
reset role;
select * from finish();
rollback;
