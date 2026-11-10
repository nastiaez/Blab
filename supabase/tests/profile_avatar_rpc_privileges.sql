-- Run on a disposable database after all canonical migrations.
\set ON_ERROR_STOP on
begin;
do $$
begin
 if has_function_privilege('anon','public.update_my_avatar(text,uuid)','EXECUTE') then
  raise exception 'anonymous avatar RPC EXECUTE remains';
 end if;
 if not has_function_privilege('authenticated','public.update_my_avatar(text,uuid)','EXECUTE') then
  raise exception 'authenticated avatar RPC EXECUTE lost';
 end if;
 raise notice 'PASS avatar RPC grants: anonymous denied, authenticated preserved';
end $$;
set local role anon;
do $$
begin
 begin
  perform public.update_my_avatar(null,null);
  raise exception 'anonymous RPC unexpectedly callable';
 exception when insufficient_privilege then
  if sqlerrm not like 'permission denied for function update_my_avatar%' then raise; end if;
  raise notice 'PASS anonymous rejected at function permission boundary';
 end;
end $$;
reset role;
rollback;
