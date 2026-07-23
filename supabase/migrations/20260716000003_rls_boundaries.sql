-- L-08: align profile, message mutation, and read-receipt authorization with
-- the invite-only product boundary.

create or replace function public.can_view_profile(target_profile_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select target_profile_id = auth.uid()
    or exists (
      select 1
      from public.chat_members me
      join public.chat_members partner
        on partner.chat_id = me.chat_id
      where me.user_id = auth.uid()
        and partner.user_id = target_profile_id
    );
$$;

revoke all on function public.can_view_profile(uuid) from public;
grant execute on function public.can_view_profile(uuid) to authenticated;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated
  using (public.can_view_profile(id));

-- Profile identity and creation time are not client-editable fields.
revoke update on table public.profiles from authenticated;
grant update (display_name, avatar_path, interface_language)
  on table public.profiles to authenticated;

create or replace function public.enforce_message_update_contract()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_body_changed boolean := new.body is distinct from old.body;
  v_deleted_changed boolean := new.deleted_at is distinct from old.deleted_at;
begin
  -- Service-role/operator maintenance is constrained by its own trusted path.
  if auth.uid() is null then
    return new;
  end if;

  if new.id is distinct from old.id
    or new.chat_id is distinct from old.chat_id
    or new.sender_id is distinct from old.sender_id
    or new.created_at is distinct from old.created_at
    or new.reply_to is distinct from old.reply_to then
    raise exception 'message_immutable_fields';
  end if;

  if v_body_changed and v_deleted_changed then
    raise exception 'message_update_conflict';
  end if;

  if v_body_changed then
    if old.deleted_at is not null then
      raise exception 'message_deleted';
    end if;
    if old.created_at < now() - interval '24 hours' then
      raise exception 'message_edit_window_expired';
    end if;
    new.edited_at := now();
  elsif new.edited_at is distinct from old.edited_at then
    raise exception 'message_edited_at_server_owned';
  end if;

  if v_deleted_changed then
    -- Clients request delete with any non-null value; the database owns the
    -- authoritative deletion time. Null remains the restore operation.
    new.deleted_at := case when new.deleted_at is null then null else now() end;
  end if;

  return new;
end;
$$;

drop trigger if exists enforce_message_update_contract on public.messages;
create trigger enforce_message_update_contract
  before update on public.messages
  for each row execute function public.enforce_message_update_contract();

drop policy if exists messages_update_sender on public.messages;
create policy messages_update_sender on public.messages
  for update to authenticated
  using (
    auth.uid() = sender_id
    and public.is_account_active(auth.uid())
    and public.is_chat_member(chat_id)
  )
  with check (
    auth.uid() = sender_id
    and public.is_account_active(auth.uid())
    and public.is_chat_member(chat_id)
  );

-- Product deletion is a soft-delete update. Physical deletion remains
-- available to trusted moderation and cascade paths only.
drop policy if exists messages_delete_sender on public.messages;
revoke update, delete on table public.messages from authenticated;
grant update (body, deleted_at) on table public.messages to authenticated;

-- Remove malformed legacy receipts before adding structural consistency.
delete from public.message_reads r
where not exists (
  select 1
  from public.messages m
  where m.id = r.message_id
    and m.chat_id = r.chat_id
    and m.sender_id <> r.user_id
)
or not exists (
  select 1
  from public.chat_members cm
  where cm.chat_id = r.chat_id
    and cm.user_id = r.user_id
);

alter table public.messages
  add constraint messages_id_chat_id_key unique (id, chat_id);

alter table public.message_reads
  add constraint message_reads_message_chat_fkey
  foreign key (message_id, chat_id)
  references public.messages (id, chat_id)
  on delete cascade;

create or replace function public.can_mark_message_read(
  target_message_id uuid,
  target_chat_id uuid,
  target_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select target_user_id = auth.uid()
    and public.is_chat_member(target_chat_id)
    and exists (
      select 1
      from public.messages m
      where m.id = target_message_id
        and m.chat_id = target_chat_id
        and m.sender_id <> target_user_id
        and m.deleted_at is null
    );
$$;

revoke all on function public.can_mark_message_read(uuid, uuid, uuid)
  from public;
grant execute on function public.can_mark_message_read(uuid, uuid, uuid)
  to authenticated;

drop policy if exists message_reads_insert_self on public.message_reads;
create policy message_reads_insert_self on public.message_reads
  for insert to authenticated
  with check (
    public.can_mark_message_read(message_id, chat_id, user_id)
  );

-- The database owns read_at; clients supply only the receipt identity.
revoke insert on table public.message_reads from authenticated;
grant insert (message_id, user_id, chat_id)
  on table public.message_reads to authenticated;

-- The security-invoker view previously relied on every client query adding a
-- viewer_id filter. Enforce that filter in the view so the reverse orientation
-- of a shared chat cannot be selected directly.
create or replace view public.chat_list with (security_invoker = true) as
select
  me.user_id                              as viewer_id,
  me.chat_id                              as chat_id,
  partner.user_id                         as partner_id,
  partner_profile.display_name            as partner_name,
  partner_profile.avatar_path             as partner_avatar,
  me.learning_language                    as my_learning,
  partner.learning_language               as partner_learning,
  last_msg.body                           as last_body,
  last_msg.created_at                     as last_at,
  coalesce(unread.cnt, 0)                 as unread_count,
  last_msg.id                             as last_message_id
from public.chat_members me
join public.chat_members partner
  on partner.chat_id = me.chat_id and partner.user_id <> me.user_id
join public.profiles partner_profile
  on partner_profile.id = partner.user_id
left join lateral (
  select id, body, created_at
  from public.messages m
  where m.chat_id = me.chat_id and m.deleted_at is null
  order by m.created_at desc
  limit 1
) last_msg on true
left join lateral (
  select count(*)::int as cnt
  from public.messages m
  where m.chat_id = me.chat_id
    and m.sender_id <> me.user_id
    and m.deleted_at is null
    and not exists (
      select 1 from public.message_reads r
      where r.message_id = m.id and r.user_id = me.user_id
    )
) unread on true
where me.user_id = auth.uid();
