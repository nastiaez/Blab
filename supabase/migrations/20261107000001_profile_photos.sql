-- BLA-39: private, versioned avatar objects; only the current object is readable.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('profile-avatars','profile-avatars',false,5242880,array['image/jpeg'])
on conflict(id) do nothing;

create policy profile_avatar_upload on storage.objects for insert to authenticated
with check(bucket_id='profile-avatars' and public.is_account_active(auth.uid())
 and name ~ ('^' || auth.uid()::text || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$'));
create policy profile_avatar_delete on storage.objects for delete to authenticated
using(bucket_id='profile-avatars' and (storage.foldername(name))[1]=auth.uid()::text);
create policy profile_avatar_read on storage.objects for select to authenticated
using(bucket_id='profile-avatars' and public.is_account_active(auth.uid()) and ((storage.foldername(name))[1]=auth.uid()::text or exists(
 select 1 from public.profiles p where p.avatar_path=name
 and p.account_deleted_at is null and public.can_view_profile(p.id))));

-- Clients cannot select another user's object or persist arbitrary tracking URLs.
revoke update(avatar_path) on public.profiles from authenticated;
-- Only INSERT initializes Google photos. No login callback/backfill can restore
-- a removed photo, replace a custom one, or follow later provider changes.
create function public.initialize_google_profile_photo() returns trigger
language plpgsql security definer set search_path=public as $$
declare source text; provider text;
begin
 select raw_app_meta_data->>'provider',coalesce(nullif(btrim(raw_user_meta_data->>'avatar_url'),''),nullif(btrim(raw_user_meta_data->>'picture'),''))
 into provider,source from auth.users where id=new.id;
 if new.avatar_path is null and provider='google' and source ~ '^https://([a-zA-Z0-9-]+\.)*googleusercontent\.com/' then
  new.avatar_path:=source;
 end if;
 return new;
end; $$;
revoke all on function public.initialize_google_profile_photo() from public;
create trigger initialize_google_profile_photo before insert on public.profiles
for each row execute function public.initialize_google_profile_photo();

-- Shared person-avatar consumers receive changes, including removal.
do $$ begin
 if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime'
 and schemaname='public' and tablename='profiles') then
  alter publication supabase_realtime add table public.profiles;
 end if;
end $$;

-- Durable cleanup survives account erasure and lost upload/commit responses.
create table public.profile_avatar_cleanup (
 object_path text primary key,actor_id uuid not null,
 status text not null default 'pending' check(status in('pending','processing','done')),
 attempts integer not null default 0,lease_token uuid,locked_at timestamptz,
 next_attempt_at timestamptz not null default now()+interval '15 minutes'
);
alter table public.profile_avatar_cleanup enable row level security;
revoke all on public.profile_avatar_cleanup from public,anon,authenticated;
grant all on public.profile_avatar_cleanup to service_role;
create function public.track_profile_avatar_upload() returns trigger
language plpgsql security definer set search_path=public as $$
begin
 if new.bucket_id='profile-avatars' then
  insert into profile_avatar_cleanup(object_path,actor_id)
  values(new.name,split_part(new.name,'/',1)::uuid) on conflict do nothing;
 end if; return new;
end; $$;
revoke all on function public.track_profile_avatar_upload() from public,anon,authenticated;
create trigger track_profile_avatar_upload after insert on storage.objects
for each row execute function public.track_profile_avatar_upload();

create function public.queue_profile_avatar_account_erasure(p_actor_id uuid)
returns setof public.profile_avatar_cleanup language plpgsql security definer set search_path=public,storage as $$
begin
 if auth.role() is distinct from 'service_role' and pg_trigger_depth()=0 then raise insufficient_privilege; end if;
 update profiles set avatar_path=null where id=p_actor_id;
 update profile_avatar_cleanup set next_attempt_at=now() where actor_id=p_actor_id and status<>'done';
 -- Auth deletion may proceed after its durable physical-cleanup work exists.
 update storage.objects set owner=null,owner_id=null where bucket_id='profile-avatars'
 and split_part(name,'/',1)=p_actor_id::text;
 return query select * from profile_avatar_cleanup where actor_id=p_actor_id and status<>'done';
end; $$;
revoke all on function public.queue_profile_avatar_account_erasure(uuid) from public,anon,authenticated;
grant execute on function public.queue_profile_avatar_account_erasure(uuid) to service_role;
create function public.capture_profile_avatar_erasure() returns trigger language plpgsql security definer set search_path=public as $$
begin perform queue_profile_avatar_account_erasure(old.id); return old; end; $$;
revoke all on function public.capture_profile_avatar_erasure() from public,anon,authenticated;
create trigger aa_profile_avatar_erasure before delete on auth.users for each row execute function public.capture_profile_avatar_erasure();

create function public.claim_profile_avatar_cleanup()
returns setof public.profile_avatar_cleanup language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
 return query with ready as(
  select q.object_path from profile_avatar_cleanup q where
  ((q.status='pending' and q.next_attempt_at<=now()) or
   (q.status='processing' and q.locked_at<now()-interval '2 minutes'))
  and not exists(select 1 from profiles p where p.avatar_path=q.object_path)
  order by q.next_attempt_at for update skip locked limit 16)
 update profile_avatar_cleanup q set status='processing',attempts=q.attempts+1,
 lease_token=gen_random_uuid(),locked_at=now() from ready r
 where q.object_path=r.object_path returning q.*;
end; $$;
create function public.finish_profile_avatar_cleanup(p_path text,p_lease uuid,p_success boolean)
returns boolean language plpgsql security definer set search_path=public as $$
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege;end if;
 if p_success then
  delete from profile_avatar_cleanup where object_path=p_path and lease_token=p_lease and status='processing';
  return found;
 end if;
 update profile_avatar_cleanup set status='pending',
 lease_token=null,locked_at=null,next_attempt_at=now()+interval '5 minutes'
 where object_path=p_path and lease_token=p_lease and status='processing';
 return found;
end; $$;
revoke all on function public.claim_profile_avatar_cleanup(),public.finish_profile_avatar_cleanup(text,uuid,boolean) from public,anon,authenticated;
grant execute on function public.claim_profile_avatar_cleanup(),public.finish_profile_avatar_cleanup(text,uuid,boolean) to service_role;

create function public.update_my_avatar(p_path text,p_expected_actor uuid) returns text
language plpgsql security definer set search_path=public,storage as $$
declare actor uuid:=auth.uid(); old_path text;
begin
 if actor is distinct from p_expected_actor then raise insufficient_privilege; end if;
 if not public.is_account_active(actor) then raise insufficient_privilege; end if;
 select avatar_path into old_path from public.profiles where id=actor for update;
 if p_path is not null then
  perform 1 from profile_avatar_cleanup where object_path=p_path and actor_id=actor and status='pending' for update;
  if not found then raise exception 'avatar_upload_expired'; end if;
 end if;
 if p_path is not null and (p_path !~ ('^'||actor::text||'/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.jpg$')
 or not exists(select 1 from storage.objects where bucket_id='profile-avatars'
 and name=p_path and metadata->>'mimetype'='image/jpeg')) then
 raise exception 'invalid_avatar_path'; end if;
 update public.profiles set avatar_path=p_path where id=actor and account_deleted_at is null;
 return old_path;
end; $$;
revoke all on function public.update_my_avatar(text,uuid) from public;
grant execute on function public.update_my_avatar(text,uuid) to authenticated;
