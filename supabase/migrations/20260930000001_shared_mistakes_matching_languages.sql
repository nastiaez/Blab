-- Preserve whether both chat participants had the same learning language when
-- each message was created. Existing messages fail closed and remain clean.

alter table public.messages
  add column languages_matched_at_send boolean not null default false;

create or replace function public.set_message_language_match()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member_count integer;
  v_language_count integer;
begin
  -- Serialize this decision with a concurrent learning-language update. The
  -- stable order avoids competing message inserts taking the rows differently.
  perform cm.user_id
  from public.chat_members cm
  where cm.chat_id = new.chat_id
  order by cm.user_id
  for share;

  select count(*), count(distinct cm.learning_language)
    into v_member_count, v_language_count
  from public.chat_members cm
  where cm.chat_id = new.chat_id;

  new.languages_matched_at_send :=
    v_member_count = 2 and v_language_count = 1;
  return new;
end;
$$;

revoke all on function public.set_message_language_match()
  from public, anon, authenticated;

create trigger set_message_language_match_before_insert
  before insert on public.messages
  for each row execute function public.set_message_language_match();
