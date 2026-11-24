-- Extend only the owned reduced fixture to execute existing real membership writers.
alter table chats alter id set default gen_random_uuid();
alter table chats add title text,add owner_id uuid,add left_at timestamptz,add member_low_id uuid,add member_high_id uuid;
create unique index fixture_active_pair on chats(member_low_id,member_high_id) where left_at is null;
alter table chat_members add history_cleared_at timestamptz;
create table group_invites(token text primary key,chat_id uuid,revoked_at timestamptz);
create table invites(token text primary key,inviter_user_id uuid,reusable boolean default true,revoked_at timestamptz,used_at timestamptz,used_by_user_id uuid,resulting_chat_id uuid);
create table push_notification_events(event_type text,source_key text,recipient_id uuid,actor_id uuid,chat_id uuid,unique(event_type,source_key,recipient_id));
