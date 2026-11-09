-- Owned disposable Supabase only. Never run against retained or hosted databases.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email,raw_user_meta_data) values
 ('81111111-1111-4111-8111-811111111111','storage-alice@blab.test','{"name":"Storage Alice"}'),
 ('82222222-2222-4222-8222-822222222222','storage-bob@blab.test','{"name":"Storage Bob"}');
insert into chats(id,member_low_id,member_high_id) values
 ('83333333-3333-4333-8333-833333333333','81111111-1111-4111-8111-811111111111','82222222-2222-4222-8222-822222222222');
insert into chat_members(chat_id,user_id,learning_language) values
 ('83333333-3333-4333-8333-833333333333','81111111-1111-4111-8111-811111111111','de'),
 ('83333333-3333-4333-8333-833333333333','82222222-2222-4222-8222-822222222222','de');
insert into messages(id,chat_id,sender_id,body) values
 ('84444444-4444-4444-8444-844444444444','83333333-3333-4333-8333-833333333333','81111111-1111-4111-8111-811111111111','Ich ist tired');
select * from claim_message_preparation_jobs_for_worker(100);
do $$ declare payload jsonb; n int; begin
 select jsonb_agg(jsonb_build_object('jobId',id,'lease',lease_token,'result',
   jsonb_build_object('mode','correction','sourceLang','de','translation','Ich bin müde',
    'interfaceText','I am tired','explanation',null,'confidence',null,'tokens','[]'::jsonb,
    'formAlternatives',jsonb_build_object('blabGenerationEnvelope',jsonb_build_object('version','a-v1','source','Ich ist tired')),
    'contractVersion','minimal-source-anchor-v11')))
 into payload from message_preparation_jobs where message_id='84444444-4444-4444-8444-844444444444';
 if not complete_translation_message_batch(payload) then raise exception 'worker batch rejected'; end if;
 select count(*) into n from message_translations where message_id='84444444-4444-4444-8444-844444444444'
  and form_alternatives->'blabGenerationEnvelope'->>'version'='a-v1';
 if n<>1 then raise exception 'shared cache lost envelope: %',n; end if;
 select count(*) into n from message_readable_variants where message_id='84444444-4444-4444-8444-844444444444'
  and result->'formAlternatives'->'blabGenerationEnvelope'->>'version'='a-v1';
 if n<>2 then raise exception 'readable viewer projections lost envelope: %',n; end if;
end $$;

do $$ declare b bytea; a bytea; begin
 select jsonb_send(form_alternatives) into b from message_translations limit 1;
 begin
  update message_translations set form_alternatives='{"blabGenerationEnvelope":{},"subjectRole":"invalid"}';
  raise exception 'malformed forms accepted';
 exception when check_violation then null; end;
 select jsonb_send(form_alternatives) into a from message_translations limit 1;
 if a is distinct from b then raise exception 'failed write mutated completed bytes'; end if;
 if normalize_translation_storage_result('{"translation":"Hallo","interfaceText":"Hello","sourceLang":"pl"}')->>'sourceLang' <> 'pl' then raise exception 'Polish source regressed'; end if;
 raise notice 'PASS actual cache constraints reject malformed forms and preserve completed bytes';
end $$;
rollback;
