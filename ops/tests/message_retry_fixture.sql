-- Run inside a transaction with the candidate migration, then roll back.
-- Like the real worker, operate on a saved job; isolate data and HTTP delivery.
create temp table retry_fixture (like public.message_preparation_jobs including defaults);
create temp table dispatch_fixture(mid uuid);
do $$
declare
  f text;
begin
  foreach f in array array['public.claim_translation_for_message(uuid)','private.translation_deadline(uuid,boolean)'] loop
    execute replace(replace(pg_get_functiondef(f::regprocedure),'public.message_preparation_jobs','pg_temp.retry_fixture'),'RETURNS SETOF pg_temp.retry_fixture','RETURNS SETOF public.message_preparation_jobs');
  end loop;
end $$;
create or replace function private.dispatch_translation(p_message_id uuid) returns void
language sql as $$ insert into pg_temp.dispatch_fixture values(p_message_id) $$;
create trigger dispatch_message_preparation_jobs after insert on retry_fixture
referencing new table as changed_jobs for each statement execute function private.translation_job_changed();
create trigger update_message_preparation_deadlines after update on retry_fixture
referencing new table as changed_jobs for each statement execute function private.translation_job_changed();
create trigger clear_message_preparation_deadlines after delete on retry_fixture
referencing old table as removed_jobs for each statement execute function private.translation_job_changed();
select set_config('request.jwt.claim.role','service_role',true);
do $$
declare
  mid uuid:=gen_random_uuid();
  seed public.message_preparation_jobs%rowtype;
  claimed record;
  original_lease uuid;
begin
  select * into strict seed from public.message_preparation_jobs limit 1;
  seed.message_id:=mid; seed.id:=gen_random_uuid(); seed.attempts:=0;
  seed.status:='queued'; seed.available_at:=clock_timestamp(); seed.locked_at:=null;
  insert into retry_fixture select (seed).*;
  if not exists(select from cron.job where jobname='blab-tr-'||mid and active) then raise exception 'missing recovery timer'; end if;
  if (select count(*) from dispatch_fixture where dispatch_fixture.mid=seed.message_id)<>1 then raise exception 'no immediate dispatch'; end if;
  select * into strict claimed from public.claim_translation_for_message(mid);
  original_lease:=claimed.lease_token;
  if claimed.attempts<>1 then raise exception 'first claim failed'; end if;
  if exists(select from public.claim_translation_for_message(mid)) then raise exception 'duplicate claim'; end if;
  update retry_fixture set locked_at=clock_timestamp()-interval '1 minute' where message_id=mid;
  perform private.translation_deadline(mid,true);
  select * into strict claimed from public.claim_translation_for_message(mid);
  if claimed.attempts<>2 or claimed.lease_token=original_lease then raise exception 'crash recovery failed'; end if;
  update retry_fixture set status='queued',locked_at=null,available_at=clock_timestamp()+interval '1 minute' where message_id=mid;
  if exists(select from public.claim_translation_for_message(mid)) then raise exception 'ignored delay'; end if;
  update retry_fixture set available_at=clock_timestamp() where message_id=mid;
  perform private.translation_deadline(mid,true);
  select * into strict claimed from public.claim_translation_for_message(mid);
  update retry_fixture set status='ready' where message_id=mid;
  if exists(select from cron.job where jobname='blab-tr-'||mid) or exists(select from public.claim_translation_for_message(mid)) then raise exception 'ready job retained'; end if;
end $$;
