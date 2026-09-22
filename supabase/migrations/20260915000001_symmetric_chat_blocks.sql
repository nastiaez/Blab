-- A block freezes sending for both participants until the blocker removes it.
-- The chat remains readable and visible as the V1 recovery surface.
create or replace function public.is_blocked_in_chat(p_chat_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.chat_members other
    join public.blocks b
      on (
        b.blocker_id = other.user_id
        and b.blocked_id = auth.uid()
      )
      or (
        b.blocker_id = auth.uid()
        and b.blocked_id = other.user_id
      )
    where other.chat_id = p_chat_id
      and other.user_id <> auth.uid()
  );
$$;

comment on function public.is_blocked_in_chat(uuid) is
  'True when either member of the direct chat has blocked the other.';
