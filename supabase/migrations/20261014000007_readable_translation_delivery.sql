-- Viewer-private, verified readable text. This is not a completed word-help
-- cache. Existing preparation leases recover metadata work after interruption.
create table public.message_readable_variants (
  message_id uuid not null references public.messages(id) on delete cascade,
  viewer_id uuid not null references public.profiles(id) on delete cascade,
  chat_id uuid not null references public.chats(id) on delete cascade,
  target_lang text not null,
  learning_language text not null,
  interface_lang text not null,
  language_revision integer not null,
  source_hash text not null check(source_hash ~ '^[0-9a-f]{64}$'),
  result jsonb not null,
  created_at timestamptz not null default now(),
  primary key(message_id,viewer_id,target_lang,interface_lang)
);
alter table public.message_readable_variants enable row level security;
revoke all on public.message_readable_variants from public,anon,authenticated;
grant select on public.message_readable_variants to authenticated;
grant all on public.message_readable_variants to service_role;
create policy readable_variant_select on public.message_readable_variants
for select to authenticated using (
 viewer_id=auth.uid() and public.is_account_active(auth.uid())
 and public.is_chat_member(chat_id)
 and exists(select 1 from public.messages m
   join public.profiles p on p.id=auth.uid()
   cross join lateral public.resolve_message_learning_era(m.id,auth.uid()) era
   where m.id=message_id and m.deleted_at is null
    and coalesce(p.primary_known_language,p.interface_language)=interface_lang
    and era.language_revision=message_readable_variants.language_revision
    and target_lang in (era.learning_language,coalesce(p.primary_known_language,p.interface_language))
    and encode(extensions.digest(convert_to(btrim(m.body),'UTF8'),'sha256'),'hex')=source_hash)
);
alter publication supabase_realtime add table public.message_readable_variants;

create function public.publish_message_readable_variant(
 p_message_id uuid,p_viewer_id uuid,p_target_lang text,p_interface_lang text,
 p_language_revision integer,p_source_hash text,p_result jsonb,
 p_cache_contract_version text
) returns boolean language plpgsql security definer set search_path=public,extensions as $$
declare v_chat uuid; v_primary text; v_era record; v_body text;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 if p_cache_contract_version is distinct from 'minimal-source-anchor-v11' then return false; end if;
 select m.chat_id,m.body,coalesce(p.primary_known_language,p.interface_language) into v_chat,v_body,v_primary
 from messages m join chat_members cm on cm.chat_id=m.chat_id and cm.user_id=p_viewer_id
 join profiles p on p.id=p_viewer_id
 where m.id=p_message_id and m.deleted_at is null and is_account_active(p_viewer_id)
 for share of m,cm,p;
 if not found then return false; end if;
 select * into v_era from resolve_message_learning_era(p_message_id,p_viewer_id);
 if not found or p_language_revision is null or v_era.language_revision is distinct from p_language_revision
   or p_target_lang is null or p_target_lang not in (v_era.learning_language,v_primary)
   or p_interface_lang is distinct from v_primary
   or encode(digest(convert_to(btrim(v_body),'UTF8'),'sha256'),'hex') is distinct from p_source_hash then return false; end if;
 if p_result is null or jsonb_typeof(p_result)<>'object'
  or not (p_result ?& array['mode','sourceLang','translation','interfaceText','explanation','confidence','formAlternatives'])
  or coalesce(p_result->>'mode','') not in ('translation','correction','none')
  or coalesce(p_result->>'sourceLang','') not in ('en','nl','fr','de','hi','it','pt','es','ta','tr','uk','other')
  or jsonb_typeof(p_result->'translation') is distinct from 'string' or btrim(p_result->>'translation')=''
  or jsonb_typeof(p_result->'interfaceText') is distinct from 'string' or btrim(p_result->>'interfaceText')=''
  or p_result ? 'tokens' then return false; end if;
 if p_result->>'mode'='none' and (p_result->>'sourceLang'<>p_target_lang or p_result->>'translation'<>btrim(v_body)) then return false; end if;
 if p_result->>'mode'='translation' and p_result->>'sourceLang'=p_target_lang then return false; end if;
 if p_result->>'mode'='correction' and (p_result->>'sourceLang'<>p_target_lang or p_result->>'translation'=btrim(v_body)
   or nullif(btrim(p_result->>'explanation'),'') is null or coalesce(p_result->>'confidence','') not in ('low','medium','high')) then return false; end if;
 if p_target_lang=p_interface_lang and p_result->>'translation'<>p_result->>'interfaceText' then return false; end if;
 insert into message_readable_variants(message_id,viewer_id,chat_id,target_lang,learning_language,interface_lang,language_revision,source_hash,result)
 values(p_message_id,p_viewer_id,v_chat,p_target_lang,v_era.learning_language,p_interface_lang,p_language_revision,p_source_hash,
  jsonb_build_object('mode',p_result->'mode','sourceLang',p_result->'sourceLang',
   'translation',p_result->'translation','interfaceText',p_result->'interfaceText',
   'explanation',p_result->'explanation','confidence',p_result->'confidence','formAlternatives',p_result->'formAlternatives'))
 on conflict(message_id,viewer_id,target_lang,interface_lang) do update set
  learning_language=excluded.learning_language,language_revision=excluded.language_revision,source_hash=excluded.source_hash,result=excluded.result,created_at=now();
 return true;
end; $$;
revoke all on function public.publish_message_readable_variant(uuid,uuid,text,text,integer,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.publish_message_readable_variant(uuid,uuid,text,text,integer,text,jsonb,text) to service_role;

create function public.invalidate_message_readable_variants() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if new.body is distinct from old.body or new.deleted_at is not null then
   delete from message_readable_variants where message_id=new.id;
 end if;
 return new;
end; $$;
revoke all on function public.invalidate_message_readable_variants() from public,anon,authenticated;
create trigger invalidate_message_readable_variants after update of body,deleted_at on public.messages
for each row execute function public.invalidate_message_readable_variants();
