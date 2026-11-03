-- Opaque, client-generated 256-bit receipts authorize status lookup only.
-- Completion is committed atomically with Auth erasure, never inferred from
-- transport failure, a missing profile, an expired JWT, or an absent session.
create table public.account_deletion_receipts (
 receipt_hash text primary key check(receipt_hash ~ '^[0-9a-f]{64}$'),
 user_id uuid,
 completed boolean not null default false,
 created_at timestamptz not null default now(),
 check((completed and user_id is null) or (not completed and user_id is not null))
);
alter table public.account_deletion_receipts enable row level security;
revoke all on public.account_deletion_receipts from public,anon,authenticated;
grant all on public.account_deletion_receipts to service_role;
create function public.begin_account_deletion(p_user_id uuid,p_receipt text)
returns void language plpgsql security definer set search_path=public,extensions as $$
declare h text;
begin
 if auth.role() is distinct from 'service_role' then raise insufficient_privilege; end if;
 if p_receipt is null or p_receipt !~ '^[0-9a-f]{64}$' or p_user_id is null then raise exception 'invalid_receipt'; end if;
 h:=encode(digest(p_receipt,'sha256'),'hex');
 if not exists(select 1 from auth.users where id=p_user_id) then raise exception 'invalid_identity'; end if;
 insert into account_deletion_receipts(receipt_hash,user_id) values(h,p_user_id) on conflict do nothing;
 if not exists(select 1 from account_deletion_receipts where receipt_hash=h and user_id=p_user_id and not completed) then raise exception 'receipt_conflict'; end if;
end; $$;
revoke all on function public.begin_account_deletion(uuid,text) from public,anon,authenticated;
grant execute on function public.begin_account_deletion(uuid,text) to service_role;
create function public.account_deletion_completed(p_receipt text)
returns boolean language sql stable security definer set search_path=public,extensions as $$
 select coalesce((select completed from account_deletion_receipts
 where p_receipt ~ '^[0-9a-f]{64}$' and receipt_hash=encode(digest(p_receipt,'sha256'),'hex')),false);
$$;
revoke all on function public.account_deletion_completed(text) from public;
grant execute on function public.account_deletion_completed(text) to anon,authenticated,service_role;
create function public.complete_account_deletion_receipts()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 -- Remove the personal association once complete; no Auth/profile FK cascade
 -- can erase the status needed to recover a committed-but-lost response.
 update account_deletion_receipts set completed=true,user_id=null where user_id=old.id;
 return old;
end; $$;
revoke all on function public.complete_account_deletion_receipts() from public,anon,authenticated;
create trigger complete_account_deletion_receipts after delete on auth.users
 for each row execute function public.complete_account_deletion_receipts();
