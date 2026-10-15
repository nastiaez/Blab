-- Extend existing self-owned push registration to iOS; preserve all token ownership checks.
alter table public.push_device_tokens drop constraint push_device_tokens_platform_check;
alter table public.push_device_tokens add constraint push_device_tokens_platform_check
  check (platform in ('android', 'ios'));

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
    previews_enabled
  ) values (
    p_token,
    v_uid,
    p_platform,
    coalesce(p_previews_enabled, true)
  )
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        previews_enabled = excluded.previews_enabled,
        updated_at = now(),
        last_seen_at = now();
end;
$$;

revoke all on function public.register_push_token(text, text, boolean)
  from public, anon;
grant execute on function public.register_push_token(text, text, boolean)
  to authenticated;
