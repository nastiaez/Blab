-- PostgreSQL truncates the generated unique-constraint name at 63 bytes;
-- remove that legacy key so language variants can coexist under the explicit
-- variant identity added in 00005.
alter table public.message_preparation_jobs
  drop constraint if exists message_preparation_jobs_message_id_viewer_id_language_revi_key;
