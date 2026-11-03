-- BLA-31 / US-035: minimized identity retains authorized recipient history.
alter table public.profiles drop constraint profiles_id_fkey;
alter table public.profiles add column account_deleted_at timestamptz;
create or replace function public.is_account_active(target_user_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select target_user_id is not null
 and exists(select 1 from auth.users u join profiles p on p.id=u.id where u.id=target_user_id and p.account_deleted_at is null)
 and public.has_distribution_access(target_user_id)
 and not exists(select 1 from account_enforcements e where e.user_id=target_user_id);
$$;
create or replace function public.handover_groups_before_account_erasure() returns trigger
language plpgsql security definer set search_path=public as $$
declare c record; next_owner uuid;
begin
 for c in select id from public.chats where chat_kind='group' and owner_id=old.id order by id for update loop
  select cm.user_id into next_owner from public.chat_members cm
   where cm.chat_id=c.id and cm.user_id<>old.id and cm.chat_left_at is null
   order by public.is_account_active(cm.user_id) desc,cm.joined_at,cm.user_id limit 1;
  if next_owner is null then delete from public.chats where id=c.id;
  else update public.chats set owner_id=next_owner where id=c.id; end if;
 end loop;
 if TG_OP='UPDATE' then return new; end if; return old;
end; $$;
-- Reuse the existing owner-selection algorithm without duplicating it.
create trigger handover_groups_before_account_tombstone before update of account_deleted_at on public.profiles
 for each row when (old.account_deleted_at is null and new.account_deleted_at is not null)
 execute function public.handover_groups_before_account_erasure();
-- Body-free durable recovery survives command/private-row minimization.
create table public.stream_account_send_fences(
 message_id uuid primary key, chat_id uuid not null, actor_id uuid not null,
 blocked_at timestamptz not null, status text not null default 'pending' check(status in ('pending','processing','done')),
 lease_token uuid,locked_at timestamptz,attempts integer not null default 0,
 next_attempt_at timestamptz not null default now()
);
alter table public.stream_account_send_fences enable row level security;
revoke all on public.stream_account_send_fences from public,anon,authenticated;
grant all on public.stream_account_send_fences to service_role;
create function public.retain_recipient_history_before_auth_erasure() returns trigger
language plpgsql security definer set search_path=public,storage as $$
begin
 update public.profiles set account_deleted_at=clock_timestamp(),display_name='Deleted account',avatar_path=null,known_languages='{}',primary_known_language=null,grammatical_form=null,interface_language='en',reading_script='native',onboarding_version=0,onboarding_stage='intro',name_confirmed_at=null,translation_language_confirmed_at=null,onboarding_completed_at=null where id=old.id;
 update storage.objects s set owner=null,owner_id=null where (s.owner=old.id or s.owner_id=old.id::text)
 and (exists(select 1 from public.message_attachments a where a.storage_bucket=s.bucket_id
 and (a.storage_path=s.name or a.preview_storage_path=s.name)) or exists(
 select 1 from stream_private_media_assets a where a.bucket_id=s.bucket_id and a.object_path=s.name and a.status='ready'));
 -- Viewer-private rows are not recipient history. Preserve identity-only
 -- memberships, blocks and language epochs needed by surviving recipients.
 delete from public.message_preparation_jobs where viewer_id=old.id;
 delete from public.message_prepared_packages where viewer_id=old.id;
 delete from public.message_readable_variants where viewer_id=old.id;
 delete from public.message_translation_attempts where viewer_id=old.id;
 delete from public.message_reads where user_id=old.id;
 update public.reports set reporter_id=null where reporter_id=old.id;
 update public.reports set reported_user_id=null where reported_user_id=old.id;
 delete from public.pending_group_invitations where user_id=old.id or invited_by=old.id;
 delete from public.group_invitation_inboxes where user_id=old.id;
 delete from public.push_notification_events where recipient_id=old.id;
 update public.push_notification_events set actor_id=null where actor_id=old.id;
 delete from public.push_device_tokens where user_id=old.id;
 update public.stream_push_devices set action='unregister',status='pending',lease_token=null,locked_at=null where owner_id=old.id;
 insert into public.stream_account_send_fences(message_id,chat_id,actor_id,blocked_at)
 select cmd.message_id,cmd.chat_id,cmd.actor_id,(select account_deleted_at from profiles where id=old.id)
 from stream_message_commands cmd join chats c on c.id=cmd.chat_id
 where (cmd.status in ('pending','processing') or not exists(select 1 from messages m where m.id=cmd.message_id)) and cmd.action in ('send','send_image') and not exists(select 1 from messages known where known.id=cmd.message_id)
 and (cmd.actor_id=old.id or (c.chat_kind='direct' and exists(select 1 from chat_members cm where cm.chat_id=c.id and cm.user_id=old.id)))
 on conflict(message_id) do nothing;
 delete from public.stream_message_commands where actor_id=old.id;
 delete from public.stream_media_uploads where actor_id=old.id;
 delete from public.invites where inviter_user_id=old.id;
 update public.invites set used_by_user_id=null where used_by_user_id=old.id;
 update public.chat_members set mode='normal',partner_grammatical_form=null,conversation_tone='informal',notifications_enabled=false where user_id=old.id;
 update public.chat_members set chat_left_at=coalesce(chat_left_at,now()) where user_id=old.id and chat_id in (select id from chats where chat_kind='group');
 update public.chats set created_at=created_at where id in (select chat_id from chat_members where user_id=old.id);
 return old;
end;$$;
create trigger aaa_retain_recipient_history before delete on auth.users for each row execute function public.retain_recipient_history_before_auth_erasure();
create or replace function public.queue_account_private_media_cleanup(p_actor_id uuid)
returns table(bucket_id text,object_path text) language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' and pg_trigger_depth()=0 then raise insufficient_privilege;end if;
 -- Recover legacy objects without scheduling retained attachments for deletion.
 insert into stream_private_media_assets as target(bucket_id,object_path,actor_id,chat_id,message_id,upload_lease,status)
 select s.bucket_id,s.name,p_actor_id,coalesce(a.chat_id,case when split_part(s.name,'/',1)~*'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then split_part(s.name,'/',1)::uuid else gen_random_uuid() end),
 coalesce(a.message_id,gen_random_uuid()),gen_random_uuid(),
 case when exists(select 1 from messages m where m.id=a.message_id and m.deleted_at is null) then 'ready' else 'pending' end
 from storage.objects s left join message_attachments a on a.storage_bucket=s.bucket_id
 and (a.storage_path=s.name or a.preview_storage_path=s.name)
 where s.bucket_id in ('message-media','stream-private-media')
 and (s.owner=p_actor_id or s.owner_id=p_actor_id::text or split_part(s.name,'/',2)=p_actor_id::text)

 on conflict on constraint stream_private_media_assets_pkey do nothing;
 update stream_private_media_assets a set status='ready',lease_token=null,locked_at=null
 where a.actor_id=p_actor_id and exists(select 1 from storage.objects s where s.bucket_id=a.bucket_id and s.name=a.object_path)
 and exists(select 1 from message_attachments ma join messages retained on retained.id=ma.message_id and retained.deleted_at is null
 where ma.storage_bucket=a.bucket_id and (ma.storage_path=a.object_path or ma.preview_storage_path=a.object_path));
 update stream_private_media_assets a set status='ready',lease_token=null,locked_at=null
 where a.actor_id=p_actor_id and exists(select 1 from storage.objects s where s.bucket_id=a.bucket_id and s.name=a.object_path)
 and (exists(select 1 from stream_message_commands cmd where cmd.message_id=a.message_id and cmd.action in ('send','send_image') and not exists(select 1 from messages known where known.id=cmd.message_id))
 or exists(select 1 from stream_account_send_fences f where f.message_id=a.message_id and f.status<>'done'));
 update stream_private_media_assets a set status='pending',next_attempt_at=now(),lease_token=null,locked_at=null
 where a.actor_id=p_actor_id
 and not exists(select 1 from stream_message_commands cmd where cmd.message_id=a.message_id and cmd.action in ('send','send_image') and not exists(select 1 from messages known where known.id=cmd.message_id))
 and not exists(select 1 from stream_account_send_fences f where f.message_id=a.message_id and f.status<>'done') and a.status<>'done'
 and not exists(select 1 from message_attachments ma join messages retained on retained.id=ma.message_id and retained.deleted_at is null where ma.storage_bucket=a.bucket_id
 and (ma.storage_path=a.object_path or ma.preview_storage_path=a.object_path))
 and not exists(select 1 from messages m where m.id=a.message_id and m.deleted_at is null);
 update storage.objects s set owner=null,owner_id=null
 where (s.owner=p_actor_id or s.owner_id=p_actor_id::text)
 and exists(select 1 from stream_private_media_assets a where a.actor_id=p_actor_id and a.bucket_id=s.bucket_id and a.object_path=s.name);
 return query select a.bucket_id,a.object_path from stream_private_media_assets a
 where a.actor_id=p_actor_id and a.status='pending';
end;$$;
create or replace function public.capture_stream_private_media_erasure() returns trigger
language plpgsql security definer set search_path=public as $$
begin perform queue_account_private_media_cleanup(old.id); return old; end;$$;
create function public.direct_chat_accepts_writes(p_chat_id uuid) returns boolean
language sql stable security definer set search_path=public as $$
 select exists(select 1 from chats c where c.id=p_chat_id and
 (c.chat_kind='group' or not exists(select 1 from chat_members cm join profiles p on p.id=cm.user_id
 where cm.chat_id=c.id and p.account_deleted_at is not null)));
$$;
revoke all on function public.direct_chat_accepts_writes(uuid) from public,anon;
grant execute on function public.direct_chat_accepts_writes(uuid) to authenticated,service_role;
create function public.reject_deleted_direct_chat_write() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if TG_TABLE_NAME<>'messages' and not public.is_account_active((to_jsonb(new)->>'actor_id')::uuid) then raise exception 'account_deleted'; end if;
 if TG_TABLE_NAME='stream_message_commands' and to_jsonb(new)->>'action'='delete' then return new; end if;
 if not public.direct_chat_accepts_writes(new.chat_id) then
  -- Only trusted canonical ingestion may recover a pre-deletion original.
  if TG_TABLE_NAME='messages' and auth.role()='service_role' and new.created_at <= (
   select min(p.account_deleted_at) from chat_members cm join profiles p on p.id=cm.user_id where cm.chat_id=new.chat_id
  ) then return new; end if;
  raise exception 'account_deleted';
 end if;
 return new;
end;$$;
create trigger reject_deleted_direct_chat_write before insert on public.messages
 for each row execute function public.reject_deleted_direct_chat_write();
create or replace view public.chat_list with (security_invoker = true) as
select
  me.user_id as viewer_id,
  me.chat_id as chat_id,
  case when c.chat_kind = 'direct' then partner.user_id end as partner_id,
  case when c.chat_kind = 'group' then c.title else partner_profile.display_name end as partner_name,
  case when c.chat_kind = 'direct' then partner_profile.avatar_path end as partner_avatar,
  me.learning_language as my_learning,
  coalesce(partner.learning_language, me.learning_language) as partner_learning,
  me.mode as my_mode,
  last_msg.body as last_body,
  coalesce(c.left_at, last_msg.created_at, c.created_at) as last_at,
  case when c.left_at is null then coalesce(unread.cnt, 0) else 0 end as unread_count,
  last_msg.id as last_message_id,
  me.translation_cutoff_at as translation_cutoff_at,
  (me.practice_language_selected_at is null and c.left_at is null)
    as needs_practice_language_selection,
  prepared.translation_text as last_practice_body,
  c.left_at as left_at,
  me.history_cleared_at as history_cleared_at,
  c.chat_kind,
  c.title as chat_title,
  c.owner_id,
  members.member_count,
  case when c.chat_kind = 'group' then me.joined_at end as ai_started_at,
  (c.chat_kind='direct' and partner_profile.account_deleted_at is not null) as partner_account_deleted
from public.chat_members me
join public.chats c on c.id = me.chat_id
join public.profiles viewer_profile on viewer_profile.id = me.user_id
left join lateral (
  select cm.user_id, cm.learning_language
  from public.chat_members cm
  where cm.chat_id = me.chat_id and cm.user_id <> me.user_id
  order by cm.joined_at, cm.user_id
  limit 1
) partner on c.chat_kind = 'direct'
left join public.profiles partner_profile on partner_profile.id = partner.user_id
cross join lateral (
  select count(*)::integer as member_count
  from public.chat_members cm join public.profiles p on p.id=cm.user_id
  where cm.chat_id = me.chat_id and cm.chat_left_at is null and p.account_deleted_at is null
) members
left join lateral (
  select id, body, created_at
  from public.messages m
  where m.chat_id = me.chat_id and m.deleted_at is null
    and m.message_type <> 'group_joined'
    and (c.chat_kind = 'group' or m.created_at >= me.joined_at)
  order by m.created_at desc
  limit 1
) last_msg on true
left join lateral (
  select package.translation_text
  from public.message_prepared_packages package
  join public.resolve_message_learning_era(last_msg.id, me.user_id) era
    on era.learning_language = package.learning_language
   and era.language_revision = package.language_revision
  where package.message_id = last_msg.id
    and package.viewer_id = me.user_id
    and public.group_ai_eligible(package.message_id,me.user_id)
    and me.practice_language_selected_at is not null
    and package.status = 'ready'
    and package.source_version = encode(extensions.digest(
      convert_to(btrim(last_msg.body), 'UTF8'), 'sha256'), 'hex')
    and package.primary_known_language = coalesce(
      viewer_profile.primary_known_language, viewer_profile.interface_language, 'en')
  limit 1
) prepared on true
left join lateral (
  select count(*)::integer as cnt
  from public.messages m
  where m.chat_id = me.chat_id
    and m.sender_id <> me.user_id
    and m.message_type <> 'group_joined'
    and m.deleted_at is null
    and m.created_at >= me.joined_at
    and not exists (
      select 1 from public.message_reads r
      where r.message_id = m.id and r.user_id = me.user_id
    )
) unread on true
where me.user_id = auth.uid() and me.hidden_at is null;

create function public.protect_deleted_identity() returns trigger language plpgsql set search_path=public as $$
begin
 if pg_trigger_depth()=1 and auth.role() is distinct from 'service_role' and
 (new.account_deleted_at is distinct from old.account_deleted_at or old.account_deleted_at is not null) then
 raise insufficient_privilege; end if;
 return new;
end;$$;
create trigger protect_deleted_identity before update on public.profiles for each row execute function public.protect_deleted_identity();
revoke all on function public.retain_recipient_history_before_auth_erasure() from public,anon,authenticated;
revoke all on function public.protect_deleted_identity() from public,anon,authenticated;
revoke all on function public.reject_deleted_direct_chat_write() from public,anon,authenticated;

create trigger reject_deleted_direct_stream_reservation before insert or update on public.stream_message_commands
 for each row execute function public.reject_deleted_direct_chat_write();

create trigger reject_deleted_direct_media_reservation before insert or update on public.stream_media_uploads
 for each row execute function public.reject_deleted_direct_chat_write();

-- Departed identities remain authors, not current group roster entries.
create or replace function public.group_members(p_chat_id uuid)
returns table(user_id uuid,display_name text,is_owner boolean)
language plpgsql stable security definer set search_path=public as $$
begin
 if not public.is_account_active(auth.uid()) or not exists(
 select 1 from chat_members me join chats c on c.id=me.chat_id where me.chat_id=p_chat_id
 and me.user_id=auth.uid() and me.chat_left_at is null and c.chat_kind='group' and c.left_at is null)
 then raise insufficient_privilege using message='group_not_available'; end if;
 return query select p.id,p.display_name,c.owner_id=p.id from chat_members cm
 join profiles p on p.id=cm.user_id join chats c on c.id=cm.chat_id
 where cm.chat_id=p_chat_id and cm.chat_left_at is null and p.account_deleted_at is null
 order by (c.owner_id=p.id) desc,cm.joined_at,p.id;
end;$$;

-- Recheck leases immediately before vendor writes, not only at reservation.
create function public.stream_command_is_writable(p_request_id uuid,p_lease_token uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from stream_message_commands cmd where cmd.request_id=p_request_id
 and cmd.lease_token=p_lease_token and cmd.status='processing'
 and is_account_active(cmd.actor_id) and (cmd.action='delete' or direct_chat_accepts_writes(cmd.chat_id))
 and exists(select 1 from chat_members cm where cm.chat_id=cmd.chat_id and cm.user_id=cmd.actor_id and cm.chat_left_at is null));
$$;
revoke all on function public.stream_command_is_writable(uuid,uuid) from public,anon,authenticated;
grant execute on function public.stream_command_is_writable(uuid,uuid) to service_role;

create or replace function public.can_read_stream_private_media(p_path text)
returns boolean language sql stable security definer set search_path=public as $$
 select is_account_active(auth.uid()) and exists(select 1 from stream_private_media_assets a
 join messages msg on msg.id=a.message_id join chat_members cm on cm.chat_id=msg.chat_id
 where a.bucket_id='stream-private-media' and a.object_path=p_path and a.status='ready'
 and cm.user_id=auth.uid() and msg.deleted_at is null
 and (cm.history_cleared_at is null or msg.created_at>cm.history_cleared_at)
 and public.group_history_visible(msg.chat_id,msg.created_at));
$$;

-- Reconcile old destructive queue entries before a cleanup worker can claim them.
update public.stream_private_media_assets a set status='ready',lease_token=null,locked_at=null
where exists(select 1 from storage.objects s where s.bucket_id=a.bucket_id and s.name=a.object_path) and (exists(select 1 from public.messages m where m.id=a.message_id and m.deleted_at is null)
or exists(select 1 from public.message_attachments ma join public.messages retained on retained.id=ma.message_id and retained.deleted_at is null where ma.storage_bucket=a.bucket_id
and (ma.storage_path=a.object_path or ma.preview_storage_path=a.object_path)));

create function public.private_media_cleanup_is_safe(p_bucket text,p_path text,p_lease_token uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from stream_private_media_assets a where a.bucket_id=p_bucket and a.object_path=p_path
 and a.lease_token=p_lease_token and a.status='processing'
 and not exists(select 1 from stream_message_commands cmd where cmd.message_id=a.message_id and cmd.action in ('send','send_image') and not exists(select 1 from messages known where known.id=cmd.message_id))
 and not exists(select 1 from stream_account_send_fences f where f.message_id=a.message_id and f.status<>'done')
 and not exists(select 1 from messages m where m.id=a.message_id and m.deleted_at is null)
 and not exists(select 1 from message_attachments ma join messages retained on retained.id=ma.message_id and retained.deleted_at is null where ma.storage_bucket=a.bucket_id
 and (ma.storage_path=a.object_path or ma.preview_storage_path=a.object_path)));
$$;
revoke all on function public.private_media_cleanup_is_safe(text,text,uuid) from public,anon,authenticated;
grant execute on function public.private_media_cleanup_is_safe(text,text,uuid) to service_role;

create function public.can_read_retained_message_media(p_path text)
returns boolean language sql stable security definer set search_path=public as $$
 select is_account_active(auth.uid()) and exists(select 1 from message_attachments a
 join messages msg on msg.id=a.message_id join chat_members cm on cm.chat_id=msg.chat_id
 where a.storage_bucket='message-media' and (a.storage_path=p_path or a.preview_storage_path=p_path)
 and cm.user_id=auth.uid() and msg.deleted_at is null
 and (cm.history_cleared_at is null or msg.created_at>cm.history_cleared_at)
 and public.group_history_visible(msg.chat_id,msg.created_at));
$$;
revoke all on function public.can_read_retained_message_media(text) from public,anon;
grant execute on function public.can_read_retained_message_media(text) to authenticated;
alter policy message_media_select_member on storage.objects using
(bucket_id='message-media' and public.can_read_retained_message_media(name));

-- Bucket participates in the legacy asset key. Never claim the same path in
-- another bucket accidentally, or claim attached recipient history.
create or replace function public.claim_stream_private_media_cleanup()
returns setof public.stream_private_media_assets language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 update stream_private_media_assets set status='failed',lease_token=null,locked_at=null
 where status='processing' and locked_at<now()-interval '2 minutes' and attempts>=16;
 update stream_private_media_assets a set status='pending',next_attempt_at=now()
 where status='uploading' and created_at<now()-interval '5 minutes'
 and not exists(select 1 from stream_media_uploads u where u.message_id=a.message_id
 and u.status='processing' and u.locked_at>now()-interval '2 minutes');
 return query with available as(select a.bucket_id,a.object_path from stream_private_media_assets a
 where ((a.status='pending' and a.next_attempt_at<=now()) or (a.status='processing' and a.locked_at<now()-interval '2 minutes'))
 and a.attempts<16
 and not exists(select 1 from stream_message_commands cmd where cmd.message_id=a.message_id and cmd.action in ('send','send_image') and not exists(select 1 from messages known where known.id=cmd.message_id))
 and not exists(select 1 from stream_account_send_fences f where f.message_id=a.message_id and f.status<>'done')
 and not exists(select 1 from messages m where m.id=a.message_id and m.deleted_at is null)
 and not exists(select 1 from message_attachments ma join messages m on m.id=ma.message_id
 where m.deleted_at is null and ma.storage_bucket=a.bucket_id and (ma.storage_path=a.object_path or ma.preview_storage_path=a.object_path))
 order by a.created_at,a.bucket_id,a.object_path for update of a skip locked limit 8)
 update stream_private_media_assets a set status='processing',attempts=a.attempts+1,lease_token=gen_random_uuid(),locked_at=now()
 from available b where a.bucket_id=b.bucket_id and a.object_path=b.object_path returning a.*;
end;$$;

create function public.media_chat_accepts_writes(p_name text)
returns boolean language plpgsql stable security definer set search_path=public as $$
declare cid uuid;
begin
 begin cid:=split_part(p_name,'/',1)::uuid;
 exception when invalid_text_representation then return false; end;
 return public.is_account_active(auth.uid()) and public.direct_chat_accepts_writes(cid);
end;$$;
revoke all on function public.media_chat_accepts_writes(text) from public,anon;
grant execute on function public.media_chat_accepts_writes(text) to authenticated;
create policy deleted_direct_media_insert on storage.objects as restrictive for insert to authenticated
with check(bucket_id<>'message-media' or public.media_chat_accepts_writes(name));
create policy deleted_direct_media_update on storage.objects as restrictive for update to authenticated
using(bucket_id<>'message-media' or public.media_chat_accepts_writes(name))
with check(bucket_id<>'message-media' or public.media_chat_accepts_writes(name));

-- Auth JWTs remain cryptographically valid until expiry. Retaining FK anchors
-- must never let one continue reading rows that used to disappear by cascade.
create function public.has_live_account_identity(p_user_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from auth.users u join profiles p on p.id=u.id
 where u.id=p_user_id and p.account_deleted_at is null);
$$;
revoke all on function public.has_live_account_identity(uuid) from public,anon;
grant execute on function public.has_live_account_identity(uuid) to authenticated,service_role;
do $$declare table_name text;
begin
 foreach table_name in array array['profiles','chats','chat_members','messages','message_reads',
 'message_reactions','message_translations','message_prepared_packages','message_preparation_jobs',
 'message_readable_variants','message_attachments','chat_language_timeline','blocks','invites',
 'group_invites','pending_group_invitations','group_invitation_inboxes','member_contact_requests',
 'group_departures','group_message_recipients'] loop
 if to_regclass('public.'||table_name) is not null then
 execute format('create policy live_account_identity_boundary on public.%I as restrictive for all to authenticated using (public.has_live_account_identity(auth.uid())) with check (public.has_live_account_identity(auth.uid()))',table_name);
 end if;
 end loop;
end;$$;
create policy live_account_storage_boundary on storage.objects as restrictive for all to authenticated
using(public.has_live_account_identity(auth.uid())) with check(public.has_live_account_identity(auth.uid()));

create or replace function public.is_chat_member(target_chat_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select public.has_live_account_identity(auth.uid()) and public.has_distribution_access(auth.uid())
 and exists(select 1 from chat_members where chat_id=target_chat_id and user_id=auth.uid());
$$;

create function public.claim_deleted_account_sends()
returns setof public.stream_account_send_fences language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 return query with available as(select message_id from stream_account_send_fences
 where (status='pending' and next_attempt_at<=now()) or (status='processing' and locked_at<now()-interval '2 minutes')
 order by blocked_at,message_id for update skip locked limit 8)
 update stream_account_send_fences f set status='processing',lease_token=gen_random_uuid(),locked_at=now(),attempts=f.attempts+1
 from available a where a.message_id=f.message_id returning f.*;
end;$$;
create function public.finish_deleted_account_send(p_message_id uuid,p_lease_token uuid,p_done boolean)
returns boolean language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 update stream_account_send_fences set status=case when p_done then 'done' else 'pending' end,
 lease_token=null,locked_at=null,next_attempt_at=now()+interval '30 seconds'
 where message_id=p_message_id and status='processing' and lease_token=p_lease_token;
 if not found then return false; end if;
 if p_done then
  update stream_private_media_assets a set status='pending',lease_token=null,locked_at=null,next_attempt_at=now()
  where a.message_id=p_message_id and a.status<>'done'
  and not exists(select 1 from messages m where m.id=a.message_id and m.deleted_at is null);
  delete from stream_account_send_fences where message_id=p_message_id and status='done';
 end if;
 return true;
end;$$;
revoke all on function public.claim_deleted_account_sends(),public.finish_deleted_account_send(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.claim_deleted_account_sends(),public.finish_deleted_account_send(uuid,uuid,boolean) to service_role;

create function public.reject_deleted_direct_message_update()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if (new.body is distinct from old.body or (old.deleted_at is not null and new.deleted_at is null))
 and not public.direct_chat_accepts_writes(new.chat_id) then raise exception 'account_deleted'; end if;
 return new;
end;$$;
create trigger reject_deleted_direct_message_update before update on public.messages
for each row execute function public.reject_deleted_direct_message_update();
revoke all on function public.reject_deleted_direct_message_update() from public,anon,authenticated;
create function public.reject_deleted_direct_reaction()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if not exists(select 1 from messages m where m.id=new.message_id and direct_chat_accepts_writes(m.chat_id))
 then raise exception 'account_deleted'; end if;
 return new;
end;$$;
create trigger reject_deleted_direct_reaction before insert or update on public.message_reactions
for each row execute function public.reject_deleted_direct_reaction();
revoke all on function public.reject_deleted_direct_reaction() from public,anon,authenticated;
