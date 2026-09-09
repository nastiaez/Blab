begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(15);

insert into public.chats (id) values ('5b070000-0000-4000-8000-000000000001');
insert into public.chat_members (chat_id, user_id, learning_language, joined_at, practice_language_selected_at)
values
 ('5b070000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-00000000000a', 'en', now() - interval '1 hour', null),
 ('5b070000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-00000000000b', 'en', now() - interval '1 hour', null);
insert into public.messages (id, chat_id, sender_id, body, created_at)
values ('5b070000-0000-4000-8000-000000000002', '5b070000-0000-4000-8000-000000000001', '00000000-0000-4000-8000-00000000000b', 'Hello there', now() - interval '30 minutes');
select is((select count(*) from public.message_preparation_jobs where chat_id = '5b070000-0000-4000-8000-000000000001'), 0::bigint, 'no language preparation before either participant chooses');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000a","role":"authenticated"}', true);
set local role authenticated;
select is((select count(*) from public.resolve_message_learning_era('5b070000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-00000000000a')), 0::bigint, 'unselected participant has no translation era');
select is(public.set_learning_language('5b070000-0000-4000-8000-000000000001', 'en'), 1::bigint, 'English is an initial choice, not a switch');
select ok((select practice_language_selected_at is not null from public.chat_members where chat_id = '5b070000-0000-4000-8000-000000000001' and user_id = auth.uid()), 'English completes required setup');
reset role;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-4000-8000-00000000000b","role":"authenticated"}', true);
set local role authenticated;
select is(public.set_learning_language('5b070000-0000-4000-8000-000000000001', 'de'), 1::bigint, 'non-English initial choice keeps revision one');
select is((select learning_language from public.resolve_message_learning_era('5b070000-0000-4000-8000-000000000002', auth.uid())), 'de', 'message received before setup uses the first chosen language');
select is((select count(*) from public.chat_language_timeline where chat_id = '5b070000-0000-4000-8000-000000000001' and user_id = auth.uid()), 1::bigint, 'initial choice creates no Now learning boundary');
reset role;
select is((select count(*) from public.message_preparation_jobs where chat_id = '5b070000-0000-4000-8000-000000000001' and viewer_id = '00000000-0000-4000-8000-00000000000b' and learning_language = 'de'), 1::bigint, 'first message is queued in the chosen language');
insert into public.message_prepared_packages (
  message_id, chat_id, viewer_id, learning_language, primary_known_language,
  language_revision, source_version, status, translation_text
) select '5b070000-0000-4000-8000-000000000002',
  '5b070000-0000-4000-8000-000000000001', id, 'de',
  coalesce(primary_known_language, interface_language, 'en'), 1,
  encode(digest(convert_to('Hello there', 'UTF8'), 'sha256'), 'hex'), 'ready', 'Hallo da'
from public.profiles where id = '00000000-0000-4000-8000-00000000000b';
set local role authenticated;
select is((select last_practice_body from public.chat_list where chat_id = '5b070000-0000-4000-8000-000000000001'), 'Hallo da', 'selected participant receives prepared Practice preview');
select is((select last_body from public.chat_list where chat_id = '5b070000-0000-4000-8000-000000000001'), 'Hello there', 'authored preview remains available as fallback');
reset role;
set local role authenticated;
select is(public.set_learning_language('5b070000-0000-4000-8000-000000000001', 'de'), 1::bigint, 'repeat choice does not reset the private revision');
select is((select learning_language from public.chat_members where chat_id = '5b070000-0000-4000-8000-000000000001' and user_id = '00000000-0000-4000-8000-00000000000a'), 'en', 'choice is private and leaves partner language unchanged');
reset role;
set local role authenticated;
select is(public.set_learning_language('5b070000-0000-4000-8000-000000000001', 'fr'), 2::bigint, 'subsequent change still advances the private timeline');
select is((select learning_language from public.resolve_message_learning_era('5b070000-0000-4000-8000-000000000002', auth.uid())), 'de', 'later changes preserve already assigned history');
reset role;
select ok(exists(select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'message_prepared_packages'), 'prepared previews announce readiness to the chat list');
select * from finish();
rollback;
