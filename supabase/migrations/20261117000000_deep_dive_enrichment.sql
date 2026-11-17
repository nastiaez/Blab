-- Deep Dive: additive private cache; shared existing quotas, no history rewrite.
create table public.message_learning_enrichments (
 viewer_id uuid not null references auth.users(id) on delete cascade,
 context_key text not null check(context_key ~ '^[0-9a-f]{64}$'),
 message_id uuid not null references public.messages(id) on delete cascade,
 source_hash text not null check(source_hash ~ '^[0-9a-f]{64}$'),
 known_lang text not null, target_lang text not null, language_revision bigint not null,
 kind text not null check(kind in ('vocabulary','correction')),
 status text not null check(status in ('processing','ready','failed')),
 lease_token uuid, locked_until timestamptz, payload jsonb,
 expires_at timestamptz not null, updated_at timestamptz not null default now(),
 primary key(viewer_id,context_key),
 check((status='processing')=(lease_token is not null)),
 check(status<>'ready' or (jsonb_typeof(payload)='object' and jsonb_typeof(payload->'meaning')='string'))
);
create index message_learning_enrichments_message on public.message_learning_enrichments(message_id);
alter table public.message_learning_enrichments enable row level security;
revoke all on public.message_learning_enrichments from public,anon,authenticated,service_role;

create function public.deep_dive_context_allowed(p_viewer uuid,p_message uuid,p_source text,p_known text,p_target text,p_revision bigint,p_kind text)
returns boolean language sql stable security definer set search_path=public,extensions,pg_temp as $$
 select exists(select 1 from public.messages m
 join public.chat_members cm on cm.chat_id=m.chat_id and cm.user_id=p_viewer
 join public.profiles p on p.id=p_viewer
 join public.chats ch on ch.id=m.chat_id
 cross join lateral public.resolve_message_learning_era(m.id,p_viewer) era
 where m.id=p_message and m.deleted_at is null and p.account_deleted_at is null
 and public.is_account_active(p_viewer) and public.has_live_account_identity(p_viewer) and public.has_distribution_access(p_viewer) and cm.mode<>'none'
 and (cm.history_cleared_at is null or m.created_at>cm.history_cleared_at)
 and (ch.chat_kind='direct' or (cm.chat_left_at is null and ch.left_at is null))
 and p.primary_known_language=p_known and era.learning_language=p_target and era.language_revision=p_revision
 and encode(digest(convert_to(btrim(m.body),'UTF8'),'sha256'),'hex')=p_source
 and (p_kind='vocabulary' or (p_kind='correction' and (m.sender_id=p_viewer or m.languages_matched_at_send is true))))
$$;
revoke all on function public.deep_dive_context_allowed(uuid,uuid,text,text,text,bigint,text) from public,anon,authenticated;
grant execute on function public.deep_dive_context_allowed(uuid,uuid,text,text,text,bigint,text) to service_role;

create function public.claim_deep_dive_enrichment(p_viewer uuid,p_message uuid,p_context text,p_source text,p_known text,p_target text,p_revision bigint,p_kind text,p_retry boolean default false)
returns jsonb language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare
 v_now timestamptz:=clock_timestamp();v_minute timestamptz;v_day date;v_chars integer;v_lease uuid;
 v_row public.message_learning_enrichments%rowtype;v_usage public.translation_usage%rowtype;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege using message='service_role_required';end if;
 if p_context is null or p_context !~ '^[0-9a-f]{64}$' or p_source is null or p_source !~ '^[0-9a-f]{64}$'
 or not public.deep_dive_context_allowed(p_viewer,p_message,p_source,p_known,p_target,p_revision,p_kind) then return jsonb_build_object('status','forbidden');end if;
 -- Serializes duplicate keys and per-viewer inflight admission; same quota row lock as translations.
 perform pg_advisory_xact_lock(hashtextextended('deep-dive:'||p_viewer::text,0));
 if not public.deep_dive_context_allowed(p_viewer,p_message,p_source,p_known,p_target,p_revision,p_kind) then return jsonb_build_object('status','forbidden');end if;
 -- Expired owners cannot publish; normalize them before capacity/pruning checks. Preserve charge/cooldown timestamps.
 update public.message_learning_enrichments set status='failed',lease_token=null,locked_until=null,payload=null where viewer_id=p_viewer and status='processing' and locked_until<=v_now;
 select * into v_row from public.message_learning_enrichments where viewer_id=p_viewer and context_key=p_context for update;
 if found then
  if v_row.message_id<>p_message or v_row.source_hash<>p_source or v_row.known_lang<>p_known or v_row.target_lang<>p_target or v_row.language_revision<>p_revision or v_row.kind<>p_kind then return jsonb_build_object('status','forbidden');end if;
  if v_row.status='ready' and v_row.expires_at>v_now then return jsonb_build_object('status','cached','analysis',v_row.payload);end if;
  if v_row.status='processing' and v_row.locked_until>v_now then return jsonb_build_object('status','pending','retryAfterSeconds',2);end if;
  if v_row.status in ('failed','processing') and (not coalesce(p_retry,false) or v_row.updated_at>v_now-interval '30 seconds') then return jsonb_build_object('status','failed','retryAfterSeconds',30);end if;
 end if;
 if (select count(*) from public.message_learning_enrichments where viewer_id=p_viewer and status='processing' and locked_until>v_now)>=2 then return jsonb_build_object('status','pending','retryAfterSeconds',2);end if;
 select char_length(btrim(body)) into v_chars from public.messages where id=p_message;
 if v_chars is null or v_chars<1 or v_chars>2000 then return jsonb_build_object('status','not_eligible');end if;
 v_minute:=date_trunc('minute',v_now);v_day:=(v_now at time zone 'utc')::date;
 insert into public.translation_usage(user_id,minute_started_at,minute_requests,day_started_at,day_requests,day_characters,updated_at)
 values(p_viewer,v_minute,0,v_day,0,0,v_now) on conflict(user_id) do nothing;
 select * into v_usage from public.translation_usage where user_id=p_viewer for update;
 if v_usage.minute_started_at<>v_minute then v_usage.minute_started_at:=v_minute;v_usage.minute_requests:=0;end if;
 if v_usage.day_started_at<>v_day then v_usage.day_started_at:=v_day;v_usage.day_requests:=0;v_usage.day_characters:=0;end if;
 if v_usage.minute_requests>=60 or v_usage.day_requests>=200 or v_usage.day_characters+v_chars>100000 then return jsonb_build_object('status','rate_limited','retryAfterSeconds',60);end if;
 update public.translation_usage set minute_started_at=v_usage.minute_started_at,minute_requests=v_usage.minute_requests+1,
 day_started_at=v_usage.day_started_at,day_requests=v_usage.day_requests+1,day_characters=v_usage.day_characters+v_chars,updated_at=v_now where user_id=p_viewer;
 -- Expired/old rows here belong ONLY to this new private cache; sentence history is untouched.
 delete from public.message_learning_enrichments where viewer_id=p_viewer and status<>'processing' and expires_at<=v_now;
 delete from public.message_learning_enrichments where viewer_id=p_viewer and context_key in
 (select context_key from public.message_learning_enrichments where viewer_id=p_viewer and status<>'processing' and context_key<>p_context order by updated_at desc offset 126);
 v_lease:=gen_random_uuid();
 insert into public.message_learning_enrichments(viewer_id,context_key,message_id,source_hash,known_lang,target_lang,language_revision,kind,status,lease_token,locked_until,expires_at,updated_at)
 values(p_viewer,p_context,p_message,p_source,p_known,p_target,p_revision,p_kind,'processing',v_lease,v_now+interval '60 seconds',v_now+interval '24 hours',v_now)
 on conflict(viewer_id,context_key) do update set status='processing',lease_token=excluded.lease_token,locked_until=excluded.locked_until,payload=null,expires_at=excluded.expires_at,updated_at=excluded.updated_at;
 return jsonb_build_object('status','claimed','lease',v_lease);
end $$;
revoke all on function public.claim_deep_dive_enrichment(uuid,uuid,text,text,text,text,bigint,text,boolean) from public,anon,authenticated;
grant execute on function public.claim_deep_dive_enrichment(uuid,uuid,text,text,text,text,bigint,text,boolean) to service_role;

create function public.finish_deep_dive_enrichment(p_viewer uuid,p_context text,p_lease uuid,p_analysis jsonb default null)
returns boolean language plpgsql security definer set search_path=public,extensions,pg_temp as $$
declare v_row public.message_learning_enrichments%rowtype;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege using message='service_role_required';end if;
 select * into v_row from public.message_learning_enrichments where viewer_id=p_viewer and context_key=p_context and status='processing' and lease_token=p_lease and locked_until>clock_timestamp() for update;
 if not found then return false;end if;
 if p_analysis is null then
  update public.message_learning_enrichments set status='failed',lease_token=null,locked_until=null,payload=null,updated_at=clock_timestamp() where viewer_id=p_viewer and context_key=p_context;return true;
 end if;
 if jsonb_typeof(p_analysis)<>'object' or jsonb_typeof(p_analysis->'meaning') is distinct from 'string' or length(p_analysis->>'meaning')=0 or octet_length(p_analysis::text)>32768
 or not public.deep_dive_context_allowed(v_row.viewer_id,v_row.message_id,v_row.source_hash,v_row.known_lang,v_row.target_lang,v_row.language_revision,v_row.kind) then
  update public.message_learning_enrichments set status='failed',lease_token=null,locked_until=null,payload=null,updated_at=clock_timestamp() where viewer_id=p_viewer and context_key=p_context;return false;
 end if;
 update public.message_learning_enrichments set status='ready',lease_token=null,locked_until=null,payload=p_analysis,updated_at=clock_timestamp() where viewer_id=p_viewer and context_key=p_context;return true;
end $$;
revoke all on function public.finish_deep_dive_enrichment(uuid,text,uuid,jsonb) from public,anon,authenticated;
grant execute on function public.finish_deep_dive_enrichment(uuid,text,uuid,jsonb) to service_role;

create function public.invalidate_deep_dive_message() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if new.body is distinct from old.body or new.deleted_at is distinct from old.deleted_at then delete from public.message_learning_enrichments where message_id=new.id;end if;return new;
end $$;
revoke all on function public.invalidate_deep_dive_message() from public,anon,authenticated,service_role;
create trigger invalidate_deep_dive_message after update of body,deleted_at on public.messages for each row execute function public.invalidate_deep_dive_message();
