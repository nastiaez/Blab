-- Existing message-media originals stay in Supabase through history migration.
-- Capture and remove them too, including older client-owned uploads which can
-- otherwise prevent the auth administrator from deleting their owner.
alter table public.stream_private_media_assets add column bucket_id text not null default 'stream-private-media' check(bucket_id in ('stream-private-media','message-media'));
alter table public.stream_private_media_assets drop constraint stream_private_media_assets_pkey;
alter table public.stream_private_media_assets add primary key(bucket_id,object_path);
create or replace function public.can_read_stream_private_media(p_path text)
returns boolean language sql stable security definer set search_path=public as $$
 select is_account_active(auth.uid()) and exists(select 1 from stream_private_media_assets a join chat_members m on m.chat_id=a.chat_id where a.bucket_id='stream-private-media' and a.object_path=p_path and a.status='ready' and m.user_id=auth.uid());
$$;

create function public.queue_account_private_media_cleanup(p_actor_id uuid)
returns table(bucket_id text,object_path text) language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' and pg_trigger_depth()=0 then raise insufficient_privilege;end if;
 if p_actor_id is null then raise exception 'invalid_actor';end if;
 insert into stream_private_media_assets as target(bucket_id,object_path,actor_id,chat_id,message_id,upload_lease,status)
 select 'message-media',s.name,p_actor_id,split_part(s.name,'/',1)::uuid,coalesce(a.message_id,gen_random_uuid()),gen_random_uuid(),'pending'
 from storage.objects s left join message_attachments a on a.storage_bucket=s.bucket_id and (a.storage_path=s.name or a.preview_storage_path=s.name)
 where s.bucket_id='message-media' and split_part(s.name,'/',2)=p_actor_id::text
  and split_part(s.name,'/',1)~*'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
 on conflict on constraint stream_private_media_assets_pkey do update set status='pending',next_attempt_at=now();
 update stream_private_media_assets a set status='pending',next_attempt_at=now()
 where a.actor_id=p_actor_id and a.status in ('ready','failed');
 return query select a.bucket_id,a.object_path from stream_private_media_assets a where a.actor_id=p_actor_id and a.status='pending';
end;$$;
revoke all on function public.queue_account_private_media_cleanup(uuid) from public,anon,authenticated;
grant execute on function public.queue_account_private_media_cleanup(uuid) to service_role;

create function public.capture_legacy_private_media_erasure()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 -- The trigger survives callers other than the app's deletion endpoint.
 perform queue_account_private_media_cleanup(old.id);
 return old;
end;$$;
revoke all on function public.capture_legacy_private_media_erasure() from public,anon,authenticated;
create trigger capture_legacy_private_media_erasure before delete on auth.users for each row execute function capture_legacy_private_media_erasure();
