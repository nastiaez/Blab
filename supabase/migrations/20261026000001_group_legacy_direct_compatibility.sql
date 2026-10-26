-- Reconcile already-group-enabled environments with the preserved legacy pair
-- contract in 20260717000002. No rows, memberships or policies are changed.
alter table public.chats drop constraint chats_kind_shape_check;
alter table public.chats add constraint chats_kind_shape_check check (
  (chat_kind = 'direct'
    and ((member_low_id is null and member_high_id is null)
      or (member_low_id is not null and member_high_id is not null))
    and title is null and owner_id is null)
  or
  (chat_kind = 'group'
    and member_low_id is null and member_high_id is null
    and char_length(btrim(title)) between 1 and 60
    and owner_id is not null)
);
