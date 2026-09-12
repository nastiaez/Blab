begin;

select plan(1);

insert into public.chats (id)
values ('58000000-0000-4000-8000-000000000001');

insert into public.chat_members (
  chat_id,
  user_id,
  learning_language,
  mode
) values
  (
    '58000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000a',
    'de',
    'normal'
  ),
  (
    '58000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000b',
    'uk',
    'practice'
  );

update public.chat_members
set learning_language = 'uk',
    mode = 'practice',
    translation_cutoff_at = null
where user_id = '00000000-0000-4000-8000-00000000000b'
  and chat_id in (
    select chat_id
    from public.chat_members
    where user_id = '00000000-0000-4000-8000-00000000000a'
  );

update public.profiles
set interface_language = 'uk',
    known_languages = array['en'],
    primary_known_language = 'en'
where id = '00000000-0000-4000-8000-00000000000b';

delete from public.translation_usage
where user_id = '00000000-0000-4000-8000-00000000000b';

insert into public.messages (id, chat_id, sender_id, body, created_at)
select
  '59000000-0000-4000-8000-000000000001',
  cm.chat_id,
  '00000000-0000-4000-8000-00000000000b',
  'Hi',
  clock_timestamp() + interval '1 second'
from public.chat_members cm
where cm.user_id = '00000000-0000-4000-8000-00000000000b'
  and cm.chat_id in (
    select chat_id
    from public.chat_members
    where user_id = '00000000-0000-4000-8000-00000000000a'
  )
limit 1;

select set_config(
  'request.jwt.claims',
  '{"role":"service_role"}',
  true
);
set local role service_role;

select ok(
  public.complete_message_translation(
    '59000000-0000-4000-8000-000000000001',
    '00000000-0000-4000-8000-00000000000b',
    'uk',
    'en',
    encode(digest(convert_to('Hi', 'UTF8'), 'sha256'), 'hex'),
    'Привіт',
    'Hi',
    'en',
    'translation',
    null,
    null,
    '[{"text":"Привіт","gloss":"Hello","roman":"Pryvit","isContent":true}]'::jsonb,
    null,
    'automatic-forms-v2'
  ),
  'completion accepts primary known language when the app language differs'
);

reset role;
select * from finish();
rollback;
