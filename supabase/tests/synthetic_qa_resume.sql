-- Canonical141 disposable PostgreSQL only; no hosted/provider proof.
begin;
do $$declare r text;s text;begin
 foreach r in array array['anon','authenticated','service_role'] loop
  foreach s in array array['blab_qa.authorize_resume(uuid,uuid,uuid,text,text,uuid,text,text)','public.claim_deep_dive_enrichment_budget140(uuid,uuid,text,text,text,text,bigint,text,boolean)'] loop
   if has_function_privilege(r,s,'execute') then raise exception 'resume privilege leak: % %',r,s;end if;
  end loop;
  if has_table_privilege(r,'blab_qa.resume_permissions','SELECT,INSERT,UPDATE,DELETE') then raise exception 'receipt exposed: %',r;end if;
 end loop;
end $$;
rollback;
