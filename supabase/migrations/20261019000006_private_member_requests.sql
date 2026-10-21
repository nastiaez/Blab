-- BLA-14: explicit acceptance, single first text, and private preview receipts.
create table public.member_contact_requests(
 chat_id uuid primary key references public.chats(id) on delete cascade,
 sender_id uuid not null references public.profiles(id),
 recipient_id uuid not null references public.profiles(id),
 accepted_at timestamptz,
 check(sender_id<>recipient_id)
);
alter table public.member_contact_requests enable row level security;
revoke all on public.member_contact_requests from public,anon,authenticated;
grant select on public.member_contact_requests to authenticated;
create policy contact_request_participants on public.member_contact_requests for select to authenticated
 using(public.is_account_active(auth.uid()) and auth.uid() in(sender_id,recipient_id));

create function public.contact_group_member(p_group_id uuid, member_id uuid, unblock boolean default false)
returns uuid language plpgsql security definer set search_path=public as $$
declare u uuid:=auth.uid(); lo uuid; hi uuid; cid uuid;
begin
 if u is null or u=member_id or not public.is_account_active(u)
   or not public.is_account_active(member_id) then raise exception 'contact_unavailable'; end if;
 perform 1 from public.chats c join public.chat_members a on a.chat_id=c.id and a.user_id=u
 join public.chat_members b on b.chat_id=c.id and b.user_id=member_id
 where c.id=p_group_id and c.chat_kind='group' and c.left_at is null
 and a.chat_left_at is null and b.chat_left_at is null for share of c;
 if not found then raise exception 'contact_unavailable'; end if;
 lo:=least(u,member_id); hi:=greatest(u,member_id);
 perform pg_advisory_xact_lock(hashtextextended(lo::text||':'||hi::text,0));
 if unblock then delete from public.blocks where blocker_id=u and blocked_id=member_id; end if;
 if exists(select 1 from public.blocks where (blocker_id=u and blocked_id=member_id)
   or (blocker_id=member_id and blocked_id=u)) then raise exception 'chat_blocked'; end if;
 select c.id into cid from public.chats c where c.member_low_id=lo
 and c.member_high_id=hi and c.left_at is null;
 if cid is not null then return cid; end if;
 insert into public.chats(member_low_id,member_high_id) values(lo,hi) returning id into cid;
 insert into public.chat_members(chat_id,user_id,learning_language,practice_language_selected_at)
 values(cid,u,'en',null),(cid,member_id,'en',null);
 insert into public.member_contact_requests(chat_id,sender_id,recipient_id) values(cid,u,member_id);
 return cid;
end; $$;

create function public.accept_member_request(p_chat_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.is_account_active(auth.uid()) or public.is_blocked_in_chat(p_chat_id)
   then raise exception 'contact_unavailable'; end if;
 update public.member_contact_requests set accepted_at=coalesce(accepted_at,now())
 where chat_id=p_chat_id and recipient_id=auth.uid();
 if not found then raise insufficient_privilege using message='request_not_available'; end if;
 delete from public.message_reads where chat_id=p_chat_id and user_id=auth.uid() and not receipt_visible;
end; $$;

create function public.block_member_request(p_chat_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare r public.member_contact_requests%rowtype;
begin
 if not public.is_account_active(auth.uid()) then raise exception 'contact_unavailable'; end if;
 select * into r from public.member_contact_requests where chat_id=p_chat_id
 and recipient_id=auth.uid() and accepted_at is null for update;
 if not found then raise insufficient_privilege using message='request_not_available'; end if;
 insert into public.blocks(blocker_id,blocked_id) values(auth.uid(),r.sender_id) on conflict do nothing;
 delete from public.chats where id=p_chat_id;
end; $$;

create function public.guard_pending_member_message()
returns trigger language plpgsql security definer set search_path=public as $$
declare r public.member_contact_requests%rowtype;
begin
 select * into r from public.member_contact_requests where chat_id=new.chat_id for update;
 if not found or r.accepted_at is not null then return new; end if;
 if TG_OP='UPDATE' then
   if new.body is distinct from old.body or new.reply_to is distinct from old.reply_to
     or new.message_type is distinct from old.message_type then raise exception 'request_pending'; end if;
   return new;
 end if;
 if new.sender_id<>r.sender_id or new.message_type<>'text' or new.reply_to is not null
   or exists(select 1 from public.messages where chat_id=new.chat_id)
   then raise exception 'request_pending'; end if;
 return new;
end; $$;
create trigger a_guard_pending_member_message before insert or update on public.messages
for each row execute function public.guard_pending_member_message();

create function public.guard_pending_request_receipt()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if exists(select 1 from public.member_contact_requests r where r.chat_id=new.chat_id
   and r.accepted_at is null) then return null; end if;
 return new;
end; $$;
create trigger a_guard_pending_request_receipt before insert or update on public.message_reads
for each row execute function public.guard_pending_request_receipt();
revoke all on function public.contact_group_member(uuid,uuid,boolean),
 public.accept_member_request(uuid),public.block_member_request(uuid) from public,anon;
grant execute on function public.contact_group_member(uuid,uuid,boolean),
 public.accept_member_request(uuid),public.block_member_request(uuid) to authenticated;
alter publication supabase_realtime add table public.member_contact_requests;
