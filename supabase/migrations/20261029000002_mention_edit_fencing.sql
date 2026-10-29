-- Identity-only edits obey the same edit/privacy rules as visible text edits.
do $$
declare f record; definition text;
begin
 for f in select oid from pg_proc where pronamespace='public'::regnamespace
   and proname in ('enforce_message_update_contract','guard_pending_member_message','guard_closed_chat_message') loop
  definition:=pg_get_functiondef(f.oid);
  definition:=replace(definition,'new.body is distinct from old.body','(new.body is distinct from old.body or new.mentions is distinct from old.mentions)');
  execute definition;
 end loop;
end$$;

create function public.invalidate_mention_edit() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if new.mentions is distinct from old.mentions then
  delete from message_translations where message_id=new.id;
  delete from message_readable_variants where message_id=new.id;
  delete from message_prepared_packages where message_id=new.id;
  -- Removing the old lease fences workers that began before the identity edit.
  delete from message_preparation_jobs where message_id=new.id;
  if new.deleted_at is null then perform enqueue_message_preparation_jobs(new.id); end if;
 end if;
 return new;
end$$;
revoke all on function public.invalidate_mention_edit() from public,anon,authenticated;
create trigger z_invalidate_mention_edit after update on public.messages
for each row execute function public.invalidate_mention_edit();

-- A late direct (non-leased) translation must not reattach an old identity.
create function public.check_translation_mention_identity() returns trigger
language plpgsql security definer set search_path=public as $$
declare expected jsonb; actual jsonb; spans jsonb; sentence text; ranges jsonb; m jsonb;
begin
 if TG_TABLE_NAME='message_prepared_packages' and to_jsonb(new)->>'status'<>'ready' then return new; end if;
 select coalesce(jsonb_agg(jsonb_build_array(x->>'userId',x->>'label') order by x->>'userId',x->>'label'),'[]'::jsonb)
 into expected from messages msg cross join lateral jsonb_array_elements(msg.mentions) x where msg.id=new.message_id;
 spans:='{}'::jsonb;
 for m in select value from jsonb_array_elements(new.tokens) loop
  if jsonb_typeof(m->'blabMentionSpans')='object' then spans:=spans||(m->'blabMentionSpans'); end if;
 end loop;
 foreach sentence in array array[new.translation_text,new.interface_text] loop
  ranges:=coalesce(spans->sentence,'[]'::jsonb);
  if jsonb_typeof(ranges)<>'array' then raise exception 'stale_mention_identity'; end if;
  select coalesce(jsonb_agg(jsonb_build_array(x->>'userId',x->>'label') order by x->>'userId',x->>'label'),'[]'::jsonb)
  into actual from jsonb_array_elements(ranges) x;
  if actual is distinct from expected then raise exception 'stale_mention_identity'; end if;
 end loop;
 return new;
end$$;
revoke all on function public.check_translation_mention_identity() from public,anon,authenticated;
create trigger check_translation_mention_identity before insert or update on public.message_translations
for each row execute function public.check_translation_mention_identity();
create trigger check_prepared_mention_identity before insert or update on public.message_prepared_packages
for each row execute function public.check_translation_mention_identity();

-- Text-first rows omit the identity sidecar. Mention messages wait for their
-- complete result instead of briefly displaying unlinked or stale names.
do $$
declare f record; definition text;
begin
 for f in select oid from pg_proc where pronamespace='public'::regnamespace and proname='publish_message_readable_variant' loop
  definition:=pg_get_functiondef(f.oid);
  definition:=replace(definition,'insert into public.message_readable_variants',
   'if exists(select 1 from public.messages where id=p_message_id and mentions<>''[]''::jsonb) then return true; end if; insert into public.message_readable_variants');
  definition:=replace(definition,'insert into message_readable_variants',
   'if exists(select 1 from public.messages where id=p_message_id and mentions<>''[]''::jsonb) then return true; end if; insert into message_readable_variants');
  execute definition;
 end loop;
end$$;
