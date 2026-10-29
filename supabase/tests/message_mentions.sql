-- Disposable seeded backend only; rollback all fixtures.
begin;
update public.app_distribution_policy set channel='public',testing_enabled=true;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
set local role authenticated;
select set_config('test.invite',(select token from public.create_invite()),true);
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
select set_config('test.chat',(select chat_id::text from public.claim_invite(current_setting('test.invite'))),true);
select set_config('test.message',gen_random_uuid()::text,true);
insert into public.messages(id,chat_id,sender_id,body,mentions)
values(current_setting('test.message')::uuid,current_setting('test.chat')::uuid,auth.uid(),'👋 @Alice',
 '[{"userId":"00000000-0000-4000-8000-00000000000a","label":"Alice","start":3}]');
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000a"}',true);
do $$begin
 if (select mentions->0->>'userId' from public.messages where id=current_setting('test.message')::uuid)<>'00000000-0000-4000-8000-00000000000a' then raise exception 'recipient identity missing'; end if;
 begin
 insert into public.messages(chat_id,sender_id,body,mentions) values(current_setting('test.chat')::uuid,auth.uid(),'@Carol','[{"userId":"00000000-0000-4000-8000-00000000000c","label":"Carol","start":0}]');
 raise exception 'outsider mention accepted';
 exception when raise_exception then if sqlerrm<>'mention_member_unavailable' then raise; end if; end;
end$$;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"00000000-0000-4000-8000-00000000000b"}',true);
update public.messages set body='Hello @Alice',mentions='[{"userId":"00000000-0000-4000-8000-00000000000a","label":"Alice","start":6}]' where id=current_setting('test.message')::uuid;
do $$begin
 if (select mentions->0->>'start' from public.messages where id=current_setting('test.message')::uuid)<>'6' then raise exception 'edit range not saved'; end if;
end$$;
update public.messages set body='Hello Alice',mentions='[]' where id=current_setting('test.message')::uuid;
-- Same visible name, different identity: invalidate and reject late old data.
update public.messages set body='@Alice',mentions='[{"userId":"00000000-0000-4000-8000-00000000000a","label":"Alice","start":0}]' where id=current_setting('test.message')::uuid;
reset role;
create temporary table mention_result_probe(message_id uuid,translation_text text,interface_text text,tokens jsonb);
create trigger probe before insert on mention_result_probe for each row execute function public.check_translation_mention_identity();
insert into mention_result_probe values(current_setting('test.message')::uuid,'@Alice','@Alice','[{"blabMentionSpans":{"@Alice":[{"userId":"00000000-0000-4000-8000-00000000000a","label":"Alice","start":0}]}}]');
set local role authenticated;
update public.messages set mentions='[{"userId":"00000000-0000-4000-8000-00000000000b","label":"Alice","start":0}]' where id=current_setting('test.message')::uuid;
reset role;
do $$begin
 begin
 insert into mention_result_probe values(current_setting('test.message')::uuid,'@Alice','@Alice','[{"blabMentionSpans":{"@Alice":[{"userId":"00000000-0000-4000-8000-00000000000a","label":"Alice","start":0}]}}]');
 raise exception 'stale identity accepted';
 exception when raise_exception then if sqlerrm<>'stale_mention_identity' then raise; end if; end;
end$$;
set local role authenticated;
-- Legacy body-only edit strips obsolete structured ranges, not a send failure.
update public.messages set body='Hello' where id=current_setting('test.message')::uuid;
do $$begin
 if (select mentions from public.messages where id=current_setting('test.message')::uuid)<>'[]'::jsonb then raise exception 'legacy edit retained invalid tag'; end if;
end$$;
reset role;
insert into public.chat_message_transports(chat_id,provider,migration_state) values(current_setting('test.chat')::uuid,'stream','active');
set local role authenticated;
select public.authorize_stream_message_command(gen_random_uuid(),current_setting('test.chat')::uuid,gen_random_uuid(),'send','@Alice',null,'[{"userId":"00000000-0000-4000-8000-00000000000a","label":"Alice","start":0}]');
-- Older clients retain the six-argument/default call contract.
select public.authorize_stream_message_command(gen_random_uuid(),current_setting('test.chat')::uuid,gen_random_uuid(),'send','Hello',null);
rollback;
