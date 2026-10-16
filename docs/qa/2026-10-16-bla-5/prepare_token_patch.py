"""Generate a fenced token-only repair from an inspected provider result.
Usage: python3 prepare_token_patch.py snapshot.json provider-result.json patch.sql
Never executes SQL. No migration or historical sentence invalidation.
"""
import json
import sys
from pathlib import Path
snapshot, fixture, destination = map(Path, sys.argv[1:])
rows = json.loads(snapshot.read_text())['rows']
assert len(rows) == 1
row = rows[0]
result = json.loads(fixture.read_text())['result']['v0']
assert row['translation_text'] == result['translation']
assert row['target_lang'] == 'en' and row['interface_lang'] == 'uk'
tokens = result['tokens']
assert ''.join(t['text'] for t in tokens) == row['translation_text']
for token in tokens:
    token['wordHelpVersion'] = 'contextual-word-meanings-v1'
    if token['isContent']:
        assert token['gloss']
assert all(t['gloss'] != 'повідомлення' for t in tokens if t['text'] in ['the', 'of'])
def sql(value):
    return "'" + str(value).replace("'", "''") + "'"
id_, source, sentence, old, new = map(sql, [row['message_id'], row['source_hash'], row['translation_text'], json.dumps(row['tokens'],ensure_ascii=False), json.dumps(tokens,ensure_ascii=False)])
statement = f'''-- Exact reported variant only; all non-token columns must remain identical.
begin;
do $repair$
declare old_shared jsonb; old_package jsonb; new_shared jsonb; new_package jsonb; count_ integer; packages_ integer;
begin
 if exists(select 1 from public.message_preparation_jobs where message_id={id_}::uuid
   and learning_language='en' and primary_known_language='uk' and status in ('queued','processing'))
 then raise exception 'Active preparation must settle before metadata repair'; end if;
 select count(*) into packages_ from public.message_prepared_packages where message_id={id_}::uuid;
 select to_jsonb(t) into strict old_shared from public.message_translations t
 where message_id={id_}::uuid and target_lang='en' and interface_lang='uk'
 and source_hash={source} and translation_text={sentence} and tokens={old}::jsonb for update;
 select to_jsonb(p) into strict old_package from public.message_prepared_packages p
 where message_id={id_}::uuid and learning_language='en' and primary_known_language='uk'
 and source_version={source} and translation_text={sentence} and status='ready' and tokens={old}::jsonb for update;
 update public.message_translations set tokens={new}::jsonb where message_id={id_}::uuid and target_lang='en' and interface_lang='uk';
 get diagnostics count_=row_count;
 if count_<>1 then raise exception 'Shared variant count mismatch'; end if;
 -- Existing shared-cache trigger refreshes resolved_at; restore its original
 -- value so this repair changes metadata only, not historical completion time.
 update public.message_prepared_packages set tokens={new}::jsonb,
 resolved_at=(old_package->>'resolved_at')::timestamptz
 where message_id={id_}::uuid and learning_language='en' and primary_known_language='uk';
 get diagnostics count_=row_count;
 if count_<>1 then raise exception 'Prepared variant count mismatch'; end if;
 select to_jsonb(t) into strict new_shared from public.message_translations t where message_id={id_}::uuid and target_lang='en' and interface_lang='uk';
 select to_jsonb(p) into strict new_package from public.message_prepared_packages p where message_id={id_}::uuid and learning_language='en' and primary_known_language='uk';
 if (old_shared-'tokens') is distinct from (new_shared-'tokens') or (old_package-'tokens') is distinct from (new_package-'tokens') then raise exception 'Nonmetadata data changed'; end if;
 if packages_<>(select count(*) from public.message_prepared_packages where message_id={id_}::uuid) then raise exception 'Unexpected package created'; end if;
end $repair$;
select 'two token arrays repaired; all non-token fields unchanged' as result;
commit;
'''
Path(destination).write_text(statement)
print('Prepared exact compare-and-swap patch for one shared + one prepared variant')
