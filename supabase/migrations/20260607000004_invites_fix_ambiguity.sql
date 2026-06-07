-- The 2026-06-07 invites migration declared `RETURNS TABLE (token
-- text, ...)` on get_invite + claim_invite, which clashes with the
-- `token` column on public.invites whenever the function body
-- references it unqualified. Postgres rejects the call at runtime
-- with "column reference \"token\" is ambiguous". Rewrite both
-- functions with an explicit table alias and OUT-parameter-safe
-- column qualifications.

create or replace function public.get_invite(invite_token text)
  returns table (
    token text,
    inviter_user_id uuid,
    inviter_name text,
    inviter_learning_language text,
    expires_at timestamptz,
    used_at timestamptz,
    status text
  ) language plpgsql security definer as $$
declare
  v_row public.invites%rowtype;
  v_name text;
begin
  select * into v_row from public.invites i where i.token = invite_token;
  if not found then
    return;
  end if;
  select coalesce(p.display_name, '') into v_name
    from public.profiles p where p.id = v_row.inviter_user_id;
  return query
    select v_row.token,
           v_row.inviter_user_id,
           v_name,
           v_row.inviter_learning_language,
           v_row.expires_at,
           v_row.used_at,
           case
             when v_row.used_at is not null then 'used'
             when v_row.expires_at < now() then 'expired'
             else 'valid'
           end;
end;
$$;

create or replace function public.claim_invite(
  invite_token text,
  my_learning_language text
) returns table (chat_id uuid)
  language plpgsql security definer as $$
declare
  v_uid uuid := auth.uid();
  v_row public.invites%rowtype;
  v_chat_id uuid;
begin
  if v_uid is null then
    raise exception 'not_signed_in';
  end if;
  if my_learning_language is null or length(my_learning_language) <> 2 then
    raise exception 'invalid_language';
  end if;
  select * into v_row from public.invites i
    where i.token = invite_token for update;
  if not found then
    raise exception 'invite_not_found';
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

  insert into public.chats default values returning id into v_chat_id;
  insert into public.chat_members (chat_id, user_id, learning_language)
    values (v_chat_id, v_uid, my_learning_language);
  insert into public.chat_members (chat_id, user_id, learning_language)
    values (v_chat_id, v_row.inviter_user_id, v_row.inviter_learning_language);

  update public.invites i
    set used_at = now(),
        used_by_user_id = v_uid,
        resulting_chat_id = v_chat_id
    where i.token = invite_token;

  return query select v_chat_id;
end;
$$;

grant execute on function public.get_invite(text) to anon, authenticated;
grant execute on function public.claim_invite(text, text) to authenticated;
