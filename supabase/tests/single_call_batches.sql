-- Local isolated DB only; transaction leaves no fixtures or queued requests.
begin;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
insert into auth.users(id,email,raw_user_meta_data) values
 ('11111111-1111-4111-8111-111111111111','batch-alice@blab.test','{"name":"Batch Alice"}'),
 ('22222222-2222-4222-8222-222222222222','batch-bob@blab.test','{"name":"Batch Bob"}');
insert into chats(id) values('33333333-3333-4333-8333-333333333333');
insert into chat_members(chat_id,user_id,learning_language) values
 ('33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111','de'),
 ('33333333-3333-4333-8333-333333333333','22222222-2222-4222-8222-222222222222','uk');
insert into messages(id,chat_id,sender_id,body) values
 ('44444444-4444-4444-8444-444444444444','33333333-3333-4333-8333-333333333333','11111111-1111-4111-8111-111111111111','Hello');
do $$ declare n integer; old_id uuid; old_token uuid; r jsonb; begin
 select count(*) into n from message_preparation_jobs where message_id='44444444-4444-4444-8444-444444444444';
 if n<>2 then raise exception 'expected two viewer jobs, got %',n; end if;
 select count(*) into n from claim_message_preparation_jobs_for_worker(1);
 if n<>2 then raise exception 'limit must not split a viewer batch, got %',n; end if;
 select count(*) into n from claim_message_preparation_jobs_for_worker(10);
 if n<>0 then raise exception 'duplicate concurrent claim'; end if;
 select id,lease_token into old_id,old_token from message_preparation_jobs limit 1;
 update message_preparation_jobs set locked_at=now()-interval '46 seconds';
 select count(*) into n from claim_message_preparation_jobs_for_worker(10);
 if n<>2 then raise exception 'reclaim failed'; end if;
 r:=leased_translation_action(old_id,old_token,'prepare');
 if r->>'status'<>'stale' then raise exception 'stale lease accepted'; end if;
 raise notice 'PASS atomic viewer grouping, duplicate claim exclusion and stale lease fencing';
end $$;
rollback;
