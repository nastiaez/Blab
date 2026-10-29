-- Disposable CI database only. All fixture writes roll back.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email,raw_user_meta_data) values
 ('a1311111-1111-4111-8111-111111111111','bla13-alice@blab.test','{"name":"Language Alice"}'),
 ('b1322222-2222-4222-8222-222222222222','bla13-bob@blab.test','{"name":"Language Bob"}');
insert into chats(id,member_low_id,member_high_id) values
 ('c1333333-3333-4333-8333-333333333333','a1311111-1111-4111-8111-111111111111','b1322222-2222-4222-8222-222222222222');
insert into chat_members(chat_id,user_id,learning_language) values
 ('c1333333-3333-4333-8333-333333333333','a1311111-1111-4111-8111-111111111111','en'),
 ('c1333333-3333-4333-8333-333333333333','b1322222-2222-4222-8222-222222222222','de');
do $$
declare
 code text; msg uuid; ok boolean; previous_count int:=0;
 alice uuid:='a1311111-1111-4111-8111-111111111111';
 bob uuid:='b1322222-2222-4222-8222-222222222222';
 chat uuid:='c1333333-3333-4333-8333-333333333333';
begin
 foreach code in array array['da','fi','ko','mr','pl'] loop
  update profiles set primary_known_language=code,known_languages=array[code,'en'],reading_script='english_letters' where id=alice;
  update chat_members set learning_language=code where chat_id=chat and user_id=alice;
  msg:=gen_random_uuid();
  insert into messages(id,chat_id,sender_id,body) values(msg,chat,bob,'Hello');
  ok:=complete_message_translation(msg,alice,code,code,encode(extensions.digest('Hello','sha256'),'hex'),'Language fixture','Known fixture',code,'translation',null,null,'[]',null);
  if not ok then raise exception 'new language result rejected: %',code; end if;
  if not exists(select 1 from message_translations where message_id=msg and target_lang=code and interface_lang=code and source_lang=code) then raise exception 'cache persistence failed: %',code; end if;
  if (select learning_language from chat_members where chat_id=chat and user_id=bob)<>'de' then raise exception 'other viewer changed'; end if;
  previous_count:=previous_count+1;
  if (select count(*) from message_translations where message_id in(select id from messages where chat_id=chat))<>previous_count then raise exception 'historical cache lost'; end if;
 end loop;
 if (select reading_script from profiles where id=bob)<>'native' then raise exception 'script leaked across accounts'; end if;
 if has_function_privilege('authenticated','public.normalize_translation_storage_result(jsonb)','execute') then raise exception 'private helper exposed'; end if;
 raise notice 'PASS all five learning/known/source languages persist independently; history and helper permissions retained';
end $$;
rollback;
