-- L-11: make a sorted participant pair the canonical identity of a direct
-- chat, consolidate exact-pair legacy duplicates, and make invite claims
-- create-or-reuse that identity atomically.

alter table public.chats
  add column member_low_id uuid,
  add column member_high_id uuid;

alter table public.chat_members
  add column translation_cutoff_at timestamptz;

-- Message/reply and receipt consistency must remain valid at commit while a
-- legacy duplicate's rows are moved to the canonical chat in one transaction.
alter table public.messages
  drop constraint messages_reply_same_chat_fkey,
  add constraint messages_reply_same_chat_fkey
    foreign key (reply_to, chat_id)
    references public.messages (id, chat_id)
    on delete set null (reply_to)
    deferrable initially immediate;

alter table public.message_reads
  drop constraint message_reads_message_chat_fkey,
  add constraint message_reads_message_chat_fkey
    foreign key (message_id, chat_id)
    references public.messages (id, chat_id)
    on delete cascade
    deferrable initially immediate;

create or replace function public.consolidate_duplicate_pair_chats()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_merged integer;
begin
  create temporary table l11_pair_candidates on commit drop as
  select
    c.id as chat_id,
    c.created_at,
    (array_agg(cm.user_id order by cm.user_id::text))[1] as member_low_id,
    (array_agg(cm.user_id order by cm.user_id::text))[2] as member_high_id
  from public.chats c
  join public.chat_members cm on cm.chat_id = c.id
  group by c.id, c.created_at
  having count(*) = 2;

  create temporary table l11_pair_ranked on commit drop as
  select
    p.*,
    first_value(p.chat_id) over (
      partition by p.member_low_id, p.member_high_id
      order by p.created_at, p.chat_id::text
    ) as canonical_chat_id,
    row_number() over (
      partition by p.member_low_id, p.member_high_id
      order by p.created_at, p.chat_id::text
    ) as pair_rank
  from l11_pair_candidates p;

  -- Option A: for existing duplicates, preserve the most recently created
  -- chat's language choice for each participant.
  create temporary table l11_latest_languages on commit drop as
  select distinct on (r.member_low_id, r.member_high_id, cm.user_id)
    r.canonical_chat_id,
    cm.user_id,
    cm.learning_language,
    r.created_at as translation_cutoff_at
  from l11_pair_ranked r
  join public.chat_members cm on cm.chat_id = r.chat_id
  order by
    r.member_low_id,
    r.member_high_id,
    cm.user_id,
    r.created_at desc,
    r.chat_id::text desc;

  select count(*) into v_merged
  from l11_pair_ranked
  where pair_rank > 1;

  set constraints messages_reply_same_chat_fkey deferred;
  set constraints message_reads_message_chat_fkey deferred;

  update public.messages m
  set chat_id = r.canonical_chat_id
  from l11_pair_ranked r
  where r.pair_rank > 1
    and m.chat_id = r.chat_id;

  update public.message_reads mr
  set chat_id = r.canonical_chat_id
  from l11_pair_ranked r
  where r.pair_rank > 1
    and mr.chat_id = r.chat_id;

  update public.invites i
  set resulting_chat_id = r.canonical_chat_id
  from l11_pair_ranked r
  where r.pair_rank > 1
    and i.resulting_chat_id = r.chat_id;

  update public.reports report
  set chat_id = r.canonical_chat_id
  from l11_pair_ranked r
  where r.pair_rank > 1
    and report.chat_id = r.chat_id;

  update public.chat_members cm
  set learning_language = latest.learning_language
  from l11_latest_languages latest
  where cm.chat_id = latest.canonical_chat_id
    and cm.user_id = latest.user_id;

  update public.chat_members cm
  set translation_cutoff_at = latest.translation_cutoff_at
  from l11_latest_languages latest
  where cm.chat_id = latest.canonical_chat_id
    and cm.user_id = latest.user_id;

  delete from public.chats c
  using l11_pair_ranked r
  where r.pair_rank > 1
    and c.id = r.chat_id;

  update public.chats c
  set member_low_id = r.member_low_id,
      member_high_id = r.member_high_id
  from l11_pair_ranked r
  where r.pair_rank = 1
    and c.id = r.canonical_chat_id;

  set constraints messages_reply_same_chat_fkey immediate;
  set constraints message_reads_message_chat_fkey immediate;

  return v_merged;
end;
$$;

revoke all on function public.consolidate_duplicate_pair_chats()
  from public, anon, authenticated;
grant execute on function public.consolidate_duplicate_pair_chats()
  to service_role;

select public.consolidate_duplicate_pair_chats();

alter table public.chats
  add constraint chats_member_pair_order_check check (
    (member_low_id is null and member_high_id is null)
    or (
      member_low_id is not null
      and member_high_id is not null
      and member_low_id::text < member_high_id::text
    )
  ),
  add constraint chats_member_low_fkey
    foreign key (member_low_id) references public.profiles (id)
    on delete cascade,
  add constraint chats_member_high_fkey
    foreign key (member_high_id) references public.profiles (id)
    on delete cascade,
  add constraint chats_member_pair_key unique (member_low_id, member_high_id);

create or replace function public.enforce_chat_pair_member()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  v_low uuid;
  v_high uuid;
begin
  select c.member_low_id, c.member_high_id
    into v_low, v_high
    from public.chats c
    where c.id = new.chat_id;

  if v_low is not null and new.user_id not in (v_low, v_high) then
    raise exception 'chat_member_outside_pair';
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_chat_pair_member()
  from public, anon, authenticated;

create trigger enforce_chat_pair_member
  before insert or update of chat_id, user_id on public.chat_members
  for each row execute function public.enforce_chat_pair_member();

-- A language change starts a new translation era for that member. Messages
-- from before the cutoff remain readable in their English original but must
-- not trigger bulk translation into the newly selected language.
create or replace function public.set_translation_cutoff_on_language_change()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.learning_language is distinct from new.learning_language then
    new.translation_cutoff_at := statement_timestamp();
  else
    new.translation_cutoff_at := old.translation_cutoff_at;
  end if;
  return new;
end;
$$;

revoke all on function public.set_translation_cutoff_on_language_change()
  from public, anon, authenticated;

create trigger set_translation_cutoff_on_language_change
  before update of learning_language
  on public.chat_members
  for each row execute function public.set_translation_cutoff_on_language_change();

-- Clients may choose a language but cannot move the cutoff backward to make
-- old history eligible for translation. Security-definer maintenance and
-- invite functions retain owner privileges for their wider updates.
revoke update on table public.chat_members from authenticated;
grant update (learning_language) on table public.chat_members to authenticated;

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
  last_msg.id                             as last_message_id,
  me.translation_cutoff_at                as translation_cutoff_at
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

create or replace function public.claim_invite(
  invite_token text,
  my_learning_language text
) returns table (chat_id uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_row public.invites%rowtype;
  v_chat_id uuid;
  v_low uuid;
  v_high uuid;
begin
  if v_uid is null then
    raise exception 'not_signed_in';
  end if;
  if not public.is_account_active(v_uid) then
    raise exception 'account_suspended';
  end if;
  if my_learning_language is null or length(my_learning_language) <> 2 then
    raise exception 'invalid_language';
  end if;

  select * into v_row from public.invites i
    where i.token = invite_token for update;
  if not found then
    raise exception 'invite_not_found';
  end if;
  if not public.is_account_active(v_row.inviter_user_id) then
    raise exception 'inviter_unavailable';
  end if;
  if v_row.used_at is not null then
    raise exception 'invite_already_claimed';
  end if;
  if v_row.expires_at < now() then
    raise exception 'invite_expired';
  end if;
  if v_row.inviter_user_id = v_uid then
    raise exception 'invite_self_claim';
  end if;

  if v_uid::text < v_row.inviter_user_id::text then
    v_low := v_uid;
    v_high := v_row.inviter_user_id;
  else
    v_low := v_row.inviter_user_id;
    v_high := v_uid;
  end if;

  -- Serialize different invite tokens for the same pair. The unique
  -- constraint remains the hard database boundary.
  perform pg_advisory_xact_lock(
    hashtextextended(v_low::text || ':' || v_high::text, 0)
  );

  insert into public.chats (member_low_id, member_high_id)
  values (v_low, v_high)
  on conflict (member_low_id, member_high_id) do nothing
  returning id into v_chat_id;

  if v_chat_id is null then
    select c.id into v_chat_id
    from public.chats c
    where c.member_low_id = v_low
      and c.member_high_id = v_high;
  end if;

  -- Option A: a successful re-invite applies both explicit new choices.
  insert into public.chat_members (chat_id, user_id, learning_language)
  values
    (v_chat_id, v_uid, my_learning_language),
    (v_chat_id, v_row.inviter_user_id, v_row.inviter_learning_language)
  on conflict on constraint chat_members_pkey do update
    set learning_language = excluded.learning_language;

  update public.invites i
  set used_at = now(),
      used_by_user_id = v_uid,
      resulting_chat_id = v_chat_id
  where i.token = invite_token;

  return query select v_chat_id;
end;
$$;

revoke all on function public.claim_invite(text, text) from public;
grant execute on function public.claim_invite(text, text) to authenticated;

comment on column public.chats.member_low_id is
  'Lower UUID in the canonical two-person chat pair; null only for unsupported legacy chat shapes.';
comment on column public.chats.member_high_id is
  'Higher UUID in the canonical two-person chat pair; null only for unsupported legacy chat shapes.';
