-- Keep network work bounded by messages, not one HTTP roundtrip per member.
create function public.prepare_translation_viewers(p_leases jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare x jsonb; r jsonb; results jsonb:='[]'::jsonb;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 if jsonb_typeof(p_leases)<>'array' or jsonb_array_length(p_leases) not between 1 and 100 then raise exception 'invalid_batch'; end if;
 for x in select value from jsonb_array_elements(p_leases) loop
  r:=public.leased_translation_action((x->>'id')::uuid,(x->>'lease')::uuid,'prepare');
  results:=results||jsonb_build_array(jsonb_build_object('id',x->>'id','prepared',r));
 end loop;
 return results;
end; $$;
revoke all on function public.prepare_translation_viewers(jsonb) from public,anon,authenticated;
grant execute on function public.prepare_translation_viewers(jsonb) to service_role;

create function public.complete_group_translation_viewers(p_entries jsonb) returns jsonb
language plpgsql security definer set search_path=public as $$
declare x jsonb; results jsonb:='[]'::jsonb; reason text;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 if jsonb_typeof(p_entries)<>'array' or jsonb_array_length(p_entries) not between 1 and 100 then raise exception 'invalid_batch'; end if;
 for x in select value from jsonb_array_elements(p_entries) loop
  reason:=null;
  begin
   if not public.complete_translation_message_batch(jsonb_build_array(x)) then reason:='batch_commit_failed'; end if;
  exception when others then
   reason:=case when sqlerrm in ('stale_batch','stale_readable','stale_completion') then 'batch_commit_'||sqlerrm else 'batch_commit_sql_'||sqlstate end;
  end;
  results:=results||jsonb_build_array(jsonb_build_object('jobId',x->>'jobId','error',reason));
 end loop;
 return results;
end; $$;
revoke all on function public.complete_group_translation_viewers(jsonb) from public,anon,authenticated;
grant execute on function public.complete_group_translation_viewers(jsonb) to service_role;

-- Normal batching continuation is not a failed provider attempt.
create function public.defer_message_preparation_leases(p_leases jsonb) returns void
language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 if jsonb_typeof(p_leases)<>'array' or jsonb_array_length(p_leases)>100 then raise exception 'invalid_batch'; end if;
 update public.message_preparation_jobs j set status='queued',locked_at=null,lease_token=null,
  attempts=greatest(0,attempts-1),available_at=clock_timestamp()
 from jsonb_to_recordset(p_leases) as x(id uuid,lease uuid)
 where j.id=x.id and j.lease_token=x.lease and j.status='processing';
end; $$;
revoke all on function public.defer_message_preparation_leases(jsonb) from public,anon,authenticated;
grant execute on function public.defer_message_preparation_leases(jsonb) to service_role;
