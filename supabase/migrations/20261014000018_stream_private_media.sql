-- Owner decision: Stream stores photo references; bytes remain private in Supabase.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('stream-private-media','stream-private-media',false,10485760,array['image/jpeg','image/png','image/webp','image/gif'])
on conflict(id) do update set public=false;

-- Asset ownership survives auth/chat cascades so interrupted uploads and account
-- deletion cannot lose their physical cleanup work. No signed URLs are retained.
create table public.stream_private_media_assets (
 object_path text primary key,
 actor_id uuid not null,chat_id uuid not null,message_id uuid not null,
 upload_lease uuid not null,
 status text not null default 'uploading' check(status in ('uploading','ready','pending','processing','done','failed')),
 attempts integer not null default 0,lease_token uuid,locked_at timestamptz,
 next_attempt_at timestamptz not null default now(),created_at timestamptz not null default now()
);
alter table public.stream_private_media_assets enable row level security;
revoke all on public.stream_private_media_assets from public,anon,authenticated;
grant all on public.stream_private_media_assets to service_role;

create policy private_stream_media_member_read on storage.objects for select to authenticated using (
 bucket_id='stream-private-media' and public.is_account_active(auth.uid()) and exists(
  select 1 from public.stream_private_media_assets a join public.chat_members m on m.chat_id=a.chat_id
  where a.object_path=storage.objects.name and a.status='ready' and m.user_id=auth.uid()
 )
);
-- The policy calls a private lookup function rather than granting queue access.
create function public.can_read_stream_private_media(p_path text)
returns boolean language sql stable security definer set search_path=public as $$
 select is_account_active(auth.uid()) and exists(select 1 from stream_private_media_assets a join chat_members m on m.chat_id=a.chat_id where a.object_path=p_path and a.status='ready' and m.user_id=auth.uid());
$$;
revoke all on function public.can_read_stream_private_media(text) from public,anon;
grant execute on function public.can_read_stream_private_media(text) to authenticated;
alter policy private_stream_media_member_read on storage.objects using(bucket_id='stream-private-media' and public.can_read_stream_private_media(name));

create function public.register_stream_private_media(p_message_id uuid,p_upload_lease uuid,p_paths text[])
returns boolean language plpgsql security definer set search_path=public as $$
declare v_upload stream_media_uploads%rowtype;v_path text;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
 select * into v_upload from stream_media_uploads where message_id=p_message_id for update;
 if not found or v_upload.status<>'processing' or v_upload.lease_token is distinct from p_upload_lease then return false;end if;
 if p_paths is null or cardinality(p_paths) not between 1 and 2 then raise exception 'invalid_private_paths';end if;
 foreach v_path in array p_paths loop
  if v_path not in (v_upload.chat_id||'/'||v_upload.actor_id||'/'||p_message_id||'/'||p_upload_lease||'/original.jpg',
   v_upload.chat_id||'/'||v_upload.actor_id||'/'||p_message_id||'/'||p_upload_lease||'/original.png',
   v_upload.chat_id||'/'||v_upload.actor_id||'/'||p_message_id||'/'||p_upload_lease||'/original.webp',
   v_upload.chat_id||'/'||v_upload.actor_id||'/'||p_message_id||'/'||p_upload_lease||'/original.gif',
   v_upload.chat_id||'/'||v_upload.actor_id||'/'||p_message_id||'/'||p_upload_lease||'/preview.jpg',
   v_upload.chat_id||'/'||v_upload.actor_id||'/'||p_message_id||'/'||p_upload_lease||'/preview.png',
   v_upload.chat_id||'/'||v_upload.actor_id||'/'||p_message_id||'/'||p_upload_lease||'/preview.webp') then raise exception 'invalid_private_paths';end if;
  insert into stream_private_media_assets(object_path,actor_id,chat_id,message_id,upload_lease)
  values(v_path,v_upload.actor_id,v_upload.chat_id,p_message_id,p_upload_lease) on conflict do nothing;
 end loop;
 return true;
end;$$;
revoke all on function public.register_stream_private_media(uuid,uuid,text[]) from public,anon,authenticated;
grant execute on function public.register_stream_private_media(uuid,uuid,text[]) to service_role;

create or replace function public.finish_stream_media_upload(p_message_id uuid,p_lease_token uuid,p_attachment jsonb)
returns boolean language plpgsql security definer set search_path=public as $$
declare v_upload stream_media_uploads%rowtype;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
 select * into v_upload from stream_media_uploads where message_id=p_message_id for update;
 if not found or v_upload.status<>'processing' or v_upload.lease_token is distinct from p_lease_token then return false;end if;
 if p_attachment is not null and p_attachment->>'blab_storage_bucket'='stream-private-media' then
  if not exists(select 1 from stream_private_media_assets where message_id=p_message_id and upload_lease=p_lease_token and status='uploading' and object_path=p_attachment->>'blab_storage_path') or
   not exists(select 1 from stream_private_media_assets where message_id=p_message_id and upload_lease=p_lease_token and status='uploading' and object_path=p_attachment->>'blab_preview_storage_path') or
   p_attachment ?| array['asset_url','thumb_url','image_url'] then raise exception 'invalid_private_attachment';end if;
 end if;
 update stream_media_uploads set status=case when p_attachment is null then 'pending' else 'ready' end,attachment=p_attachment,lease_token=null,locked_at=null where message_id=p_message_id;
 update stream_private_media_assets set status=case when p_attachment is null then 'pending' else 'ready' end,next_attempt_at=now()
 where message_id=p_message_id and upload_lease=p_lease_token and status='uploading';
 return true;
end;$$;

create function public.capture_stream_private_media_erasure()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 update stream_private_media_assets set status='pending',lease_token=null,locked_at=null,next_attempt_at=now()+interval '2 minutes'
 where actor_id=old.id and status in ('uploading','ready','processing','failed');
 return old;
end;$$;
revoke all on function public.capture_stream_private_media_erasure() from public,anon,authenticated;
create trigger capture_stream_private_media_erasure before delete on auth.users for each row execute function capture_stream_private_media_erasure();

create function public.claim_stream_private_media_cleanup()
returns setof public.stream_private_media_assets language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
 update stream_private_media_assets set status='failed',lease_token=null,locked_at=null
 where status='processing' and locked_at<now()-interval '2 minutes' and attempts>=16;
 update stream_private_media_assets a set status='pending',next_attempt_at=now()
 where status='uploading' and created_at<now()-interval '5 minutes' and not exists(select 1 from stream_media_uploads u where u.message_id=a.message_id and u.status='processing' and u.locked_at>now()-interval '2 minutes');
 return query with available as(select a.object_path from stream_private_media_assets a
  where ((a.status='pending' and next_attempt_at<=now()) or (a.status='processing' and locked_at<now()-interval '2 minutes')) and a.attempts<16
  order by a.created_at,a.object_path for update skip locked limit 8)
 update stream_private_media_assets a set status='processing',attempts=a.attempts+1,lease_token=gen_random_uuid(),locked_at=now()
 from available b where a.object_path=b.object_path returning a.*;
end;$$;
revoke all on function public.claim_stream_private_media_cleanup() from public,anon,authenticated;
grant execute on function public.claim_stream_private_media_cleanup() to service_role;
create function public.finish_stream_private_media_cleanup(p_path text,p_lease_token uuid,p_success boolean)
returns boolean language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
 update stream_private_media_assets set status=case when p_success then 'done' when attempts>=16 then 'failed' else 'pending' end,
  lease_token=null,locked_at=null,next_attempt_at=now()+least(interval '1 hour',interval '15 seconds'*power(2,least(attempts,8)))
 where object_path=p_path and status='processing' and lease_token=p_lease_token;
 return found;
end;$$;
revoke all on function public.finish_stream_private_media_cleanup(text,uuid,boolean) from public,anon,authenticated;
grant execute on function public.finish_stream_private_media_cleanup(text,uuid,boolean) to service_role;
