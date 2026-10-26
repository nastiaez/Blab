alter table public.push_device_tokens add column ios_presentation text, add column ios_capability_version integer, add column account_epoch text;
alter function public.register_push_token(text,text,boolean) rename to register_legacy_push_token;
revoke all on function public.register_legacy_push_token(text,text,boolean) from public,anon,authenticated;
create function public.register_push_token(p_token text,p_platform text,p_previews_enabled boolean)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 perform public.register_legacy_push_token(p_token,p_platform,p_previews_enabled);
 update public.push_device_tokens set ios_presentation=null,ios_capability_version=null,account_epoch=null where token=p_token and user_id=auth.uid();
end; $$;
revoke all on function public.register_push_token(text,text,boolean) from public,anon;
grant execute on function public.register_push_token(text,text,boolean) to authenticated;
create function public.register_communication_ios_push_token(p_token text,p_previews_enabled boolean,p_account_epoch text,p_capability_version integer)
returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 if p_capability_version is distinct from 1 or p_account_epoch is null or p_account_epoch !~ '^[A-Za-z0-9_-]{16,128}$' or p_previews_enabled is null then raise exception 'invalid_ios_capability'; end if;
 perform public.register_push_token(p_token,'ios',p_previews_enabled);
 update public.push_device_tokens set ios_presentation='blab_communication_v1',ios_capability_version=1,account_epoch=p_account_epoch where token=p_token and user_id=auth.uid() and platform='ios';
end; $$;
revoke all on function public.register_communication_ios_push_token(text,boolean,text,integer) from public,anon;
grant execute on function public.register_communication_ios_push_token(text,boolean,text,integer) to authenticated;
-- JSON row inspection avoids referencing absent group columns on production 105.
create function public.validate_communication_ios_push_dispatch(p_event_id uuid,p_token text,p_account_epoch text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare e public.push_notification_events%rowtype; d public.push_device_tokens%rowtype; c jsonb; m jsonb; member jsonb; actor jsonb; v_group boolean; v_count integer;
begin
 select * into e from public.push_notification_events where id=p_event_id and status='processing';
 if not found or e.event_type<>'chat_message' then return null; end if;
 select * into d from public.push_device_tokens where token=p_token and user_id=e.recipient_id and platform='ios' and ios_presentation='blab_communication_v1' and ios_capability_version=1 and account_epoch=p_account_epoch;
 if not found or not public.is_account_active(e.recipient_id) or not public.is_account_active(e.actor_id) then return null; end if;
 select to_jsonb(x) into c from public.chats x where id=e.chat_id;
 select to_jsonb(x) into m from public.messages x where id::text=e.source_key and chat_id=e.chat_id and sender_id=e.actor_id;
 select to_jsonb(x) into member from public.chat_members x where chat_id=e.chat_id and user_id=e.recipient_id;
 select to_jsonb(x) into actor from public.chat_members x where chat_id=e.chat_id and user_id=e.actor_id;
 if c is null or m is null or member is null or actor is null or c->>'left_at' is not null or member->>'chat_left_at' is not null or actor->>'chat_left_at' is not null then return null; end if;
 v_group := coalesce(c->>'chat_kind','direct')='group';
 if v_group then
 execute 'select count(*) from public.chat_members where chat_id=$1 and chat_left_at is null and user_id<>$2' into v_count using e.chat_id,e.actor_id;
 if not coalesce((member->>'notifications_enabled')::boolean,false) or (m->>'created_at')::timestamptz < (member->>'joined_at')::timestamptz or m->>'message_type'='group_joined' then return null; end if;
 else
 if exists(select 1 from public.blocks b where (b.blocker_id=e.actor_id and b.blocked_id=e.recipient_id) or (b.blocker_id=e.recipient_id and b.blocked_id=e.actor_id)) then return null; end if;
 end if;
 return jsonb_build_object('previews_enabled',d.previews_enabled,'group_title',case when v_group then c->>'title' end,'recipient_count',v_count);
end; $$;
revoke all on function public.validate_communication_ios_push_dispatch(uuid,text,text) from public,anon,authenticated;
grant execute on function public.validate_communication_ios_push_dispatch(uuid,text,text) to service_role;
