-- Read/emoji indexes below are projections, never a second writable authority.
-- Read receipts remain explicit per-message (not a vendor prefix that marks
-- unseen messages). Device privacy OFF never calls the activity endpoint.
create function public.authorize_stream_activity(p_chat_id uuid,p_action text,p_message_ids uuid[] default '{}',p_emoji text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_uid uuid:=auth.uid();v_ids uuid[];
begin
 if v_uid is null or not is_account_active(v_uid) or not is_chat_member(p_chat_id) then raise insufficient_privilege using message='chat_not_available'; end if;
 if not exists(select 1 from chat_message_transports where chat_id=p_chat_id and provider='stream' and migration_state='active') then raise exception 'stream_not_enabled'; end if;
 if p_action not in ('read','react','unreact','typing.start','typing.stop') or p_action is null or coalesce(cardinality(p_message_ids),0)>50 then raise exception 'invalid_activity'; end if;
 if p_action in ('typing.start','typing.stop') then
  if exists(select 1 from chat_members a join chat_members b on b.chat_id=a.chat_id and b.user_id<>a.user_id join blocks blocked on (blocked.blocker_id=a.user_id and blocked.blocked_id=b.user_id) or (blocked.blocker_id=b.user_id and blocked.blocked_id=a.user_id) where a.chat_id=p_chat_id and a.user_id=v_uid) then return jsonb_build_object('status','ignored'); end if;
  return jsonb_build_object('status','authorized','actorId',v_uid,'messageIds','[]'::jsonb);
 end if;
 if p_action='react' and (p_emoji is null or char_length(btrim(p_emoji)) not between 1 and 32 or p_emoji<>btrim(p_emoji)) then raise exception 'invalid_reaction'; end if;
 select coalesce(array_agg(m.id order by m.id),'{}'::uuid[]) into v_ids from messages m
 where m.id=any(p_message_ids) and m.chat_id=p_chat_id and m.deleted_at is null and (p_action<>'read' or m.sender_id<>v_uid);
 if p_action in ('react','unreact') and (cardinality(v_ids)<>1 or cardinality(p_message_ids)<>1) then raise insufficient_privilege using message='message_not_available'; end if;
 return jsonb_build_object('status','authorized','actorId',v_uid,'messageIds',to_jsonb(v_ids));
end; $$;
revoke all on function public.authorize_stream_activity(uuid,text,uuid[],text) from public,anon;
grant execute on function public.authorize_stream_activity(uuid,text,uuid[],text) to authenticated;

create table public.stream_activity_versions (
 message_id uuid primary key references public.messages(id) on delete cascade,
 occurred_at timestamptz not null
);
alter table public.stream_activity_versions enable row level security;
revoke all on public.stream_activity_versions from public,anon,authenticated;
grant all on public.stream_activity_versions to service_role;

create function public.apply_stream_message_activity(p_chat_id uuid,p_snapshot jsonb,p_occurred_at timestamptz)
returns text language plpgsql security definer set search_path=public as $$
declare v_id uuid:=(p_snapshot->>'id')::uuid;v_sender uuid;v_previous timestamptz;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 if p_occurred_at is null or p_snapshot->>'cid' is distinct from 'blab:'||p_chat_id::text then raise exception 'invalid_stream_activity'; end if;
 if not exists(select 1 from chat_message_transports where chat_id=p_chat_id and provider='stream' and migration_state='active') then return 'ignored_unmigrated'; end if;
 select sender_id into v_sender from messages where id=v_id and chat_id=p_chat_id;
 if not found or v_sender is distinct from (p_snapshot#>>'{user,id}')::uuid then raise exception 'activity_source_missing'; end if;
 perform pg_advisory_xact_lock(hashtextextended('activity:'||v_id::text,0));
 select occurred_at into v_previous from stream_activity_versions where message_id=v_id;
 if found and p_occurred_at<=v_previous then return 'stale'; end if;
 if jsonb_typeof(coalesce(p_snapshot->'blab_read_by','[]'::jsonb))<>'array' or jsonb_typeof(coalesce(p_snapshot->'latest_reactions','[]'::jsonb))<>'array' then raise exception 'invalid_stream_activity'; end if;
 -- Only the paired recipient can contribute a receipt, never the author.
 insert into message_reads(message_id,chat_id,user_id,receipt_visible)
 select v_id,p_chat_id,cm.user_id,true from chat_members cm
 where cm.chat_id=p_chat_id and cm.user_id<>v_sender
  and coalesce(p_snapshot->'blab_read_by','[]'::jsonb) ? cm.user_id::text
 on conflict(message_id,user_id) do nothing;
 -- At most two reactions exist: the native command enforces one per person.
 delete from message_reactions where message_id=v_id;
 insert into message_reactions(message_id,chat_id,user_id,emoji,created_at)
 select distinct on (cm.user_id) v_id,p_chat_id,cm.user_id,coalesce(r->>'blab_emoji',r->>'emoji_code',r->>'type'),coalesce(nullif(r->>'created_at','')::timestamptz,p_occurred_at)
 from jsonb_array_elements(coalesce(p_snapshot->'latest_reactions','[]'::jsonb)) r
 join chat_members cm on cm.chat_id=p_chat_id and cm.user_id::text=coalesce(r->>'user_id',r#>>'{user,id}')
 where char_length(btrim(coalesce(r->>'blab_emoji',r->>'emoji_code',r->>'type'))) between 1 and 32 and coalesce(r->>'blab_emoji',r->>'emoji_code',r->>'type')=btrim(coalesce(r->>'blab_emoji',r->>'emoji_code',r->>'type'))
 order by cm.user_id,coalesce(nullif(r->>'created_at','')::timestamptz,p_occurred_at) desc;
 insert into stream_activity_versions(message_id,occurred_at) values(v_id,p_occurred_at)
 on conflict(message_id) do update set occurred_at=excluded.occurred_at;
 return 'applied';
end; $$;
revoke all on function public.apply_stream_message_activity(uuid,jsonb,timestamptz) from public,anon,authenticated;
grant execute on function public.apply_stream_message_activity(uuid,jsonb,timestamptz) to service_role;

create function public.enforce_stream_activity_projection_authority() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' and exists(select 1 from chat_message_transports where chat_id=coalesce(new.chat_id,old.chat_id) and provider='stream' and migration_state='active') then raise exception 'stream_activity_server_owned'; end if;
 return coalesce(new,old);
end; $$;
revoke all on function public.enforce_stream_activity_projection_authority() from public,anon,authenticated;
create trigger a_enforce_stream_read_projection before insert or update or delete on message_reads for each row execute function enforce_stream_activity_projection_authority();
create trigger a_enforce_stream_reaction_projection before insert or update or delete on message_reactions for each row execute function enforce_stream_activity_projection_authority();

-- Do not fetch two snapshots of the same message concurrently. A late HTTP
-- result must not resurrect an emoji removed by the next event.
create index stream_event_message_work on stream_event_inbox(message_id,status,received_at,event_id);
create or replace function public.claim_stream_message_events(p_limit integer default 8)
returns setof public.stream_event_inbox language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 update stream_event_inbox set status='failed',lease_token=null,locked_at=null,last_error='lease_retry_limit'
  where status='processing' and locked_at<now()-interval '2 minutes' and attempts>=8;
 return query with candidates as (
  select e.event_id from stream_event_inbox e
  where ((e.status='pending' and e.next_attempt_at<=now()) or (e.status='processing' and e.locked_at<now()-interval '2 minutes'))
   and not exists(select 1 from stream_event_inbox busy where busy.message_id=e.message_id and busy.status='processing' and busy.locked_at>=now()-interval '2 minutes')
   and e.event_id=(select first.event_id from stream_event_inbox first where first.message_id=e.message_id and ((first.status='pending' and first.next_attempt_at<=now()) or (first.status='processing' and first.locked_at<now()-interval '2 minutes')) order by first.received_at,first.event_id limit 1)
   and pg_try_advisory_xact_lock(hashtextextended('stream-claim:'||e.message_id::text,0))
  order by e.received_at,e.event_id for update skip locked limit greatest(1,least(coalesce(p_limit,8),32))
 ) update stream_event_inbox e set status='processing',attempts=e.attempts+1,locked_at=now(),lease_token=gen_random_uuid() from candidates c where e.event_id=c.event_id returning e.*;
end; $$;
