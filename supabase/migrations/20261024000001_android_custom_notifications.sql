-- Opt-in only: existing/rolled-back clients keep OS-rendered notifications.
alter table public.push_device_tokens add column android_custom_notifications boolean not null default false;

create or replace function public.register_push_token(
  p_token text,
  p_platform text,
  p_previews_enabled boolean
) returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not_signed_in';
  end if;
  if not public.is_account_active(v_uid) then
    raise exception 'account_suspended';
  end if;
  if p_platform is null or p_platform not in ('android', 'ios')
      or p_token is null
      or length(p_token) not between 20 and 4096 then
    raise exception 'invalid_push_token';
  end if;

  insert into public.push_device_tokens (
    token,
    user_id,
    platform,
    previews_enabled,
    android_custom_notifications
  ) values (
    p_token,
    v_uid,
    p_platform,
    coalesce(p_previews_enabled, true),
    false
  )
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        previews_enabled = excluded.previews_enabled,
        android_custom_notifications = false,
        updated_at = now(),
        last_seen_at = now();
end;
$$;

revoke all on function public.register_push_token(text, text, boolean)
  from public, anon;
grant execute on function public.register_push_token(text, text, boolean)
  to authenticated;

create function public.register_custom_android_push_token(p_token text, p_previews_enabled boolean)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public.register_push_token(p_token, 'android', p_previews_enabled);
  update public.push_device_tokens set android_custom_notifications = true
    where token = p_token and user_id = auth.uid() and platform = 'android';
end;
$$;
revoke all on function public.register_custom_android_push_token(text, boolean) from public, anon;
grant execute on function public.register_custom_android_push_token(text, boolean) to authenticated;
