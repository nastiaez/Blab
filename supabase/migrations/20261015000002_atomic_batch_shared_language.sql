-- Keep each processing lease owned by the atomic writer until its own completion.
-- Legacy single-result publication still finishes matching jobs normally.
create or replace function public.mark_message_preparation_job_ready()
returns trigger language plpgsql security definer set search_path=public,extensions as $$
begin
 update public.message_preparation_jobs
 set status='ready',locked_at=null,last_error=null
 where message_id=new.message_id and learning_language=new.target_lang
   and primary_known_language=new.interface_lang and source_version=new.source_hash
   and status in ('queued','processing')
   and not (status='processing' and coalesce(current_setting('blab.atomic_translation_batch',true),'')='on');
 return new;
end; $$;

create or replace function public.complete_translation_message_batch(p_results jsonb)
returns boolean language plpgsql security definer set search_path=public,extensions as $$
declare r jsonb; v_message uuid; j public.message_preparation_jobs%rowtype; v_previous_batch text;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 if jsonb_typeof(p_results)<>'array' or jsonb_array_length(p_results) not between 1 and 4 then raise exception 'invalid_batch'; end if;
 v_previous_batch:=current_setting('blab.atomic_translation_batch',true);
 perform set_config('blab.atomic_translation_batch','on',true);
 -- Transactional: a stale viewer must not leave a half-written group.
 for r in select value from jsonb_array_elements(p_results) order by value->>'jobId' loop
  select * into j from public.message_preparation_jobs where id=(r->>'jobId')::uuid
    and lease_token=(r->>'lease')::uuid and status='processing' for update;
  if not found then raise exception 'stale_batch'; end if;
  if v_message is not null and v_message<>j.message_id then raise exception 'mixed_batch'; end if;
  v_message:=j.message_id;
  if public.leased_translation_action(j.id,j.lease_token,'readable',jsonb_build_object('result',(r->'result')-'tokens','contractVersion',r->'result'->>'contractVersion'))<>'true'::jsonb then raise exception 'stale_readable'; end if;
  if public.leased_translation_action(j.id,j.lease_token,'complete',r->'result')<>'true'::jsonb then raise exception 'stale_completion'; end if;
 end loop;
 perform set_config('blab.atomic_translation_batch',coalesce(v_previous_batch,''),true);
 return true;
end; $$;
revoke all on function public.complete_translation_message_batch(jsonb) from public,anon,authenticated;
grant execute on function public.complete_translation_message_batch(jsonb) to service_role;
