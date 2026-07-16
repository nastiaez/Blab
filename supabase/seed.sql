-- Local-only accounts for repeatable invite, messaging, and RLS testing.
-- This file is applied by `supabase db reset`; it is never pushed remotely.

delete from auth.users
where id in (
  '00000000-0000-4000-8000-00000000000a',
  '00000000-0000-4000-8000-00000000000b',
  '00000000-0000-4000-8000-00000000000c'
);

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  confirmation_token,
  recovery_token,
  email_change_token_new,
  email_change,
  email_change_token_current,
  reauthentication_token,
  phone_change,
  phone_change_token,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-00000000000a',
    'authenticated',
    'authenticated',
    'alice@blab.test',
    extensions.crypt('Blab-local-123!', extensions.gen_salt('bf')),
    now(),
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"name":"Alice Local"}'::jsonb,
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-00000000000b',
    'authenticated',
    'authenticated',
    'bob@blab.test',
    extensions.crypt('Blab-local-123!', extensions.gen_salt('bf')),
    now(),
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"name":"Bob Local"}'::jsonb,
    now(),
    now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-4000-8000-00000000000c',
    'authenticated',
    'authenticated',
    'carol@blab.test',
    extensions.crypt('Blab-local-123!', extensions.gen_salt('bf')),
    now(),
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '',
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"name":"Carol Local"}'::jsonb,
    now(),
    now()
  );

insert into auth.identities (
  provider_id,
  user_id,
  identity_data,
  provider,
  last_sign_in_at,
  created_at,
  updated_at
)
select
  id::text,
  id,
  jsonb_build_object(
    'sub', id::text,
    'email', email,
    'email_verified', true,
    'phone_verified', false
  ),
  'email',
  now(),
  now(),
  now()
from auth.users
where id in (
  '00000000-0000-4000-8000-00000000000a',
  '00000000-0000-4000-8000-00000000000b',
  '00000000-0000-4000-8000-00000000000c'
);

-- A fresh local reset revokes DML default privileges. Restore only the client
-- operations represented by the existing RLS policies and Flutter services.
grant select, update on table public.profiles to authenticated;
grant select on table public.chats to authenticated;
grant select, update on table public.chat_members to authenticated;
grant select, insert, update, delete on table public.messages to authenticated;
grant select, insert on table public.message_reads to authenticated;
grant select, insert on table public.message_translations to authenticated;
grant select, insert, delete on table public.blocks to authenticated;
grant select, insert on table public.reports to authenticated;
grant select on table public.chat_list to authenticated;
