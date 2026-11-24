#!/usr/bin/env python3
"""Owner21696: execute actual migration/functions in an owned network-none tmpfs PG.
Requires the cached PostgreSQL container blab_language_21696 started per QA report.
Does not connect to Supabase projects or touch other containers/databases.
"""
from pathlib import Path
import subprocess,re,json,concurrent.futures,time,os
ROOT=Path(__file__).resolve().parents[1];NAME='blab_language_21696'
DATABASE=os.environ.get('BLAB_LOCAL_TEST_DB','postgres')
assert re.fullmatch(r'postgres|onboarding_21696_[a-z0-9_]+',DATABASE)
def sql(source):
 r=subprocess.run(['docker','exec','-i',NAME,'psql','-h','/tmp/localdb','-U','postgres','-d',DATABASE,'-v','ON_ERROR_STOP=1','-X','-q'],input=source,text=True,capture_output=True)
 if r.returncode:raise RuntimeError(r.stdout+r.stderr)
 return r.stdout

def function(path,name):
 s=(ROOT/path).read_text();m=re.search(r'create (?:or replace )?function public\.'+name+r'\s*\([\s\S]*?\$\$;',s,re.I);assert m,name;return m.group(0)

info=json.loads(subprocess.check_output(['docker','inspect',NAME],text=True))[0]
assert info['HostConfig']['NetworkMode']=='none' and '/tmp/localdb' in info['HostConfig']['Tmpfs']
sql((ROOT/'supabase/tests/database/onboarding_learning_default_fixture.sql').read_text())
sql((ROOT/'supabase/migrations/20260930000002_versioned_onboarding.sql').read_text())
seed='supabase/migrations/20260831000001_seed_initial_language_timeline.sql'
sql(function(seed,'seed_initial_chat_language_timeline')+'\ncreate trigger seed_initial_chat_language_timeline after insert on chat_members for each row execute function seed_initial_chat_language_timeline();')
old='supabase/migrations/20260907000002_invite_first_language_setup.sql'
for f in ['set_translation_cutoff_on_language_change','record_legacy_learning_language_change','set_learning_language']:sql(function(old,f))
sql('grant execute on function set_learning_language(uuid,text) to authenticated;create trigger cutoff before update of learning_language on chat_members for each row execute function set_translation_cutoff_on_language_change();create trigger legacy after update of learning_language on chat_members for each row execute function record_legacy_learning_language_change();')
for letter in 'abcdef':
 stage='complete' if letter=='c' else 'name' if letter=='e' else 'language'
 sql("insert into profiles(id,interface_language,known_languages,primary_known_language,onboarding_version,onboarding_stage,active) values('00000000-0000-4000-8000-00000000000%s','%s',%s,%s,1,'%s',%s);"%(letter,'uk' if letter=='a' else 'de',"array['en']" if letter=='a' else "'{}'","'en'" if letter=='a' else 'null',stage,'false' if letter=='d' else 'true'))
sql("insert into chats values('00000000-0000-4000-8000-000000000055','direct');insert into chat_members(chat_id,user_id,learning_language) values('00000000-0000-4000-8000-000000000055','00000000-0000-4000-8000-00000000000c','en');insert into message_prepared_packages(payload) values('historical-result');insert into message_preparation_jobs(payload) values('historical-job');")
sql((ROOT/'supabase/migrations/20261123000001_onboarding_learning_default.sql').read_text())
print(sql((ROOT/'supabase/tests/database/onboarding_learning_default.sql').read_text()))
sql((ROOT/'supabase/tests/database/onboarding_learning_default_writers_fixture.sql').read_text())
for path,name in [('supabase/migrations/20261016000004_chat_lifecycle.sql','claim_invite_in_namespace'),('supabase/migrations/20261019000001_group_create_invite_join.sql','create_group'),('supabase/migrations/20261019000001_group_create_invite_join.sql','join_group')]:sql(function(path,name))
print(sql((ROOT/'supabase/tests/database/onboarding_learning_default_writers.sql').read_text()))

# Actual concurrent sessions serialize account completion; no mixed/stale pair.
a="begin;set local role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000000f',true);select confirm_my_onboarding_languages(1,'ko','fi');select pg_sleep(1);commit;"
b="set role authenticated;select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000000f',false);select confirm_my_onboarding_languages(1,'mr','pl');"
with concurrent.futures.ThreadPoolExecutor() as e:
 first=e.submit(sql,a);time.sleep(.25);second=e.submit(sql,b);first.result();second.result()
sql("select test_assert((select default_learning_language='ko' and primary_known_language='fi' from profiles where id='00000000-0000-4000-8000-00000000000f'),'concurrent completion mixed/lost preferences');")
print('Concurrent account-bound completion PASS; actual PostgreSQL row-lock serialization exercised')
