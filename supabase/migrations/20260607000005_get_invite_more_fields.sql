-- Extend get_invite with two more fields so the inviter's "your own
-- invite" branches can render a useful follow-up: `resulting_chat_id`
-- lets the claimed-self screen jump straight into the chat that came
-- out of the invite, and `claimed_by_name` lets the same screen show
-- who joined ("Aswin joined ✓"). Postgres won't change a function's
-- return type via CREATE OR REPLACE, so we drop the old definition
-- first.

drop function if exists public.get_invite(text);

create function public.get_invite(invite_token text)
  returns table (
    token text,
    inviter_user_id uuid,
    inviter_name text,
    inviter_learning_language text,
    expires_at timestamptz,
    used_at timestamptz,
    status text,
    resulting_chat_id uuid,
    claimed_by_name text
  ) language plpgsql security definer as $$
declare
  v_row public.invites%rowtype;
  v_inviter_name text;
  v_claimer_name text;
begin
  select * into v_row from public.invites i where i.token = invite_token;
  if not found then
    return;
  end if;
  select coalesce(p.display_name, '') into v_inviter_name
    from public.profiles p where p.id = v_row.inviter_user_id;
  select coalesce(p.display_name, '') into v_claimer_name
    from public.profiles p where p.id = v_row.used_by_user_id;
  return query
    select v_row.token,
           v_row.inviter_user_id,
           v_inviter_name,
           v_row.inviter_learning_language,
           v_row.expires_at,
           v_row.used_at,
           case
             when v_row.used_at is not null then 'used'
             when v_row.expires_at < now() then 'expired'
             else 'valid'
           end,
           v_row.resulting_chat_id,
           v_claimer_name;
end;
$$;

grant execute on function public.get_invite(text) to anon, authenticated;
