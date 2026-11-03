begin;
select set_config('test.receipt_owner',gen_random_uuid()::text,true);
select set_config('test.receipt_other',gen_random_uuid()::text,true);
insert into auth.users(id,instance_id,aud,role,email,raw_user_meta_data)
 select id,'00000000-0000-0000-0000-000000000000','authenticated','authenticated',id::text||'@receipt.blab.test','{}'::jsonb
 from unnest(array[current_setting('test.receipt_owner')::uuid,current_setting('test.receipt_other')::uuid]) id;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select public.begin_account_deletion(current_setting('test.receipt_owner')::uuid,repeat('a',64));
select public.begin_account_deletion(current_setting('test.receipt_owner')::uuid,repeat('a',64));
do $$ begin
 if public.account_deletion_completed(repeat('a',64)) then raise exception 'premature_completion'; end if;
 begin
  perform public.begin_account_deletion(current_setting('test.receipt_other')::uuid,repeat('a',64));
  raise exception 'receipt_reassigned';
 exception when others then if sqlerrm<>'receipt_conflict' then raise; end if; end;
 -- Rollback after actual trigger execution must also rollback completion.
 begin
  delete from auth.users where id=current_setting('test.receipt_owner')::uuid;
  raise exception 'rollback_fixture';
 exception when raise_exception then if sqlerrm<>'rollback_fixture' then raise; end if; end;
 if public.account_deletion_completed(repeat('a',64)) then raise exception 'rollback_marked_complete'; end if;
end $$;
select set_config('request.jwt.claims','{"role":"anon"}',true);
set local role anon;
do $$ begin
 if public.account_deletion_completed(repeat('a',64)) or public.account_deletion_completed(repeat('b',64)) then raise exception 'pending_status_leak'; end if;
 begin perform * from public.account_deletion_receipts; raise exception 'table_read_allowed';exception when insufficient_privilege then null;end;
 begin perform public.begin_account_deletion(current_setting('test.receipt_owner')::uuid,repeat('c',64));raise exception 'anon_can_begin';exception when insufficient_privilege then null;end;
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
delete from auth.users where id=current_setting('test.receipt_owner')::uuid;
do $$ begin
 if not public.account_deletion_completed(repeat('a',64)) then raise exception 'commit_not_recorded'; end if;
 if exists(select 1 from account_deletion_receipts where completed and user_id is not null) then raise exception 'personal_link_retained'; end if;
 if public.account_deletion_completed(repeat('b',64)) then raise exception 'unknown_receipt_succeeded'; end if;
end $$;
rollback;
