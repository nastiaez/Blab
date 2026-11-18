#!/usr/bin/env python3
"""CI disposable PostgreSQL only. SQL mocks are NOT hosted/provider proof."""
import argparse,concurrent.futures,hashlib,json,os,pathlib,re,subprocess,threading
p=argparse.ArgumentParser();p.add_argument('--container',required=True);p.add_argument('--output',default='build/qa-budget-sql');a=p.parse_args()
assert os.environ.get('CI')=='true','Only CI-owned disposable database'
assert re.fullmatch(r'supabase_db_[A-Za-z0-9_]+',a.container)
r=pathlib.Path(__file__).resolve().parent.parent;o=pathlib.Path(a.output);o.mkdir(parents=True,exist_ok=True)
cmd=['docker','exec','-i','-e','PGOPTIONS=-c statement_timeout=20000 -c lock_timeout=10000',a.container,'psql','-X','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-qAt']
def sql(name,q,ok=True):
 z=subprocess.run(cmd,input=q,text=True,capture_output=True,timeout=30);(o/(name+'.out')).write_text(z.stdout);(o/(name+'.err')).write_text(z.stderr)
 if ok and z.returncode:raise AssertionError(name+': '+z.stderr)
 return z
V='de111111-1111-4111-8111-111111111111';B='de222222-2222-4222-8222-222222222222';C='de444444-4444-4444-8444-444444444444';M='de555555-5555-4555-8555-555555555555';R='de666666-6666-4666-8666-666666666666';H=hashlib.sha256(b'Ayer yo va al mercado.').hexdigest()
def service(q):return "begin;set local request.jwt.claims='{\"role\":\"service_role\"}';"+q+';commit;'
def val(z):return [x for x in z.stdout.splitlines() if x.strip()][-1]
def parallel(name,q,n=8,ok=True):
 barrier=threading.Barrier(n)
 def one(i):barrier.wait();return sql(name+str(i),service(q),ok)
 with concurrent.futures.ThreadPoolExecutor(max_workers=n) as e:return list(e.map(one,range(n)))
fixture=(r/'supabase/tests/deep_dive_enrichment.sql').read_text().split('create temp table dd_test_state')[0].replace("'dd","'de").replace("'Hola mundo'","'Ayer yo va al mercado.'")
fixture=fixture.replace("insert into public.messages",f"update public.chat_members set practice_language_selected_at=null where user_id='{B}';insert into public.messages")
fixture=fixture.replace(f"'{B}','Ayer yo va al mercado.'",f"'{V}','Ayer yo va al mercado.'")
sql('fixture',"select set_config('blab.allow_deep_dive_fixture','isolated-local-only',false);"+fixture+f"insert into blab_qa.actors values('{V}'),('{B}');insert into blab_qa.runs(id,project,state) values('{R}','tpfksdljkfnenjfdbane','open');insert into blab_qa.subjects(actor,run_id,chat_id,message_id,source_hash,base_viewer,vocabulary_key,correction_key) values('{V}','{R}','{C}','{M}','{H}',true,repeat('a',64),repeat('b',64)),('{B}','{R}','{C}','{M}','{H}',false,null,null);insert into blab_qa.slots(run_id,kind,reservation_nano) values('{R}','base',12000000),('{R}','vocabulary',10000000),('{R}','correction',10000000);commit;")
job=json.loads(val(sql('job',f"update public.message_preparation_jobs set status='processing',locked_at=clock_timestamp(),lease_token=gen_random_uuid() where message_id='{M}' and viewer_id='{V}' returning json_build_object('id',id,'lease',lease_token);")));J=job['id'];L=job['lease']
reserve=f"select public.qa_reserve_worker_slot('{J}','{L}')"
z=parallel('reserve-base-',reserve,ok=False);assert sum(t.returncode==0 for t in z)==1;nonce=val(next(t for t in z if t.returncode==0))
def dispatch(kind,key,nonce,job='null',lease='null'):
 return f"select public.qa_provider_dispatch('{M}','{H}','{kind}','{nonce}',{job},{lease})"
assert val(sql('wrong-lease',service(dispatch('base','',nonce,f"'{J}'","gen_random_uuid()"))))=='f'
sql('expire-lease',f"update public.message_preparation_jobs set locked_at=clock_timestamp()-interval '46 seconds' where id='{J}';")
assert val(sql('expired-lease',service(dispatch('base','',nonce,f"'{J}'",f"'{L}'"))))=='f'
sql('renew-fixture',f"update public.message_preparation_jobs set locked_at=clock_timestamp() where id='{J}';")
z=parallel('dispatch-base-',dispatch('base','',nonce,f"'{J}'",f"'{L}'"));assert sum(val(t)=='t' for t in z)==1
assert sql('base-no-retry',service(reserve),False).returncode!=0

def claim(kind,key,viewer=V,source=H):return f"select public.claim_hosted_qa_deep_dive_enrichment('{viewer}','{M}',repeat('{key}',64),'{source}','en','es',1,'{kind}',false)"
barrier=threading.Barrier(4)
def deep(i):
 kind,key=('vocabulary','a') if i<2 else ('correction','b');barrier.wait();return kind,key,json.loads(val(sql('deep-claim-'+str(i),service(claim(kind,key)))))
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as e:got=list(e.map(deep,range(4)))
assert sorted(v['status'] for _,_,v in got)==['claimed','claimed','pending','pending']
for kind,key,v in got:
 if v['status']!='claimed':continue
 z=parallel('dispatch-'+kind+'-',dispatch(kind,key,v['qaNonce']));assert sum(val(t)=='t' for t in z)==1
 assert val(sql('finish-'+kind,service(f"select public.finish_deep_dive_enrichment('{V}',repeat('{key}',64),'{v['lease']}', '{{\"meaning\":\"SQL MOCK ONLY\"}}'::jsonb)")))=='t'
 assert json.loads(val(sql('new-process-cache-'+kind,service(claim(kind,key)))))['status']=='cached'
assert json.loads(val(sql('wrong-viewer',service(claim('vocabulary','a',B)))))['status']=='forbidden'
assert json.loads(val(sql('wrong-source',service(claim('vocabulary','a',source='c'*64)))))['status']=='forbidden'
snap=json.loads(val(sql('budget-snapshot',f"select json_build_object('reserved',(select reserved_nano from blab_qa.runs where id='{R}'),'dispatched',(select count(*) from blab_qa.slots where run_id='{R}' and dispatched_at is not null),'requests',(select day_requests from public.translation_usage where user_id='{V}'),'characters',(select day_characters from public.translation_usage where user_id='{V}'));")))
assert snap=={'reserved':32000000,'dispatched':3,'requests':2,'characters':44},snap
sql('close-run',f"update blab_qa.runs set state='closed' where id='{R}';")
assert json.loads(val(sql('closed-cache',service(claim('vocabulary','a')))))['status']=='forbidden'
assert val(sql('closed-redispatch',service(dispatch('base','',nonce,f"'{J}'",f"'{L}'"))))=='f'
for role in ['anon','authenticated','service_role']:
 assert sql('table-acl-'+role,'begin;set local role '+role+';select * from blab_qa.slots;rollback;',False).returncode!=0
for role in ['anon','authenticated']:
 assert sql('rpc-acl-'+role,'begin;set local role '+role+';'+reserve+';rollback;',False).returncode!=0
(o/'PASS.json').write_text(json.dumps({'parallelBaseReservation':1,'parallelDispatchPerKind':1,'restartCache':True,'wrongActorSourceLeaseClosedDenied':True,'aclDenied':5,'maximumAdditionalNanoUSD':32000000,'maximumTotalNanoUSD':79504985,'snapshot':snap,'providerCalls':0,'hostedWrites':False,'mockSQLOnlyNotProviderProof':True},indent=2));print((o/'PASS.json').read_text())

# Separate owned 141 SQL mock fixture; never provider proof.
V=V.replace('de','df',1);B=B.replace('de','df',1);C=C.replace('de','df',1);M=M.replace('de','df',1);R=R.replace('de','df',1)
f=fixture.replace('de111111','df111111').replace('de222222','df222222').replace('de333333','df333333').replace('de444444','df444444').replace('de555555','df555555')
sql('resume-fixture',"select set_config('blab.allow_deep_dive_fixture','isolated-local-only',false);"+f+f"insert into blab_qa.actors values('{V}'),('{B}');insert into blab_qa.runs(id,project,state) values('{R}','tpfksdljkfnenjfdbane','open');insert into blab_qa.subjects(actor,run_id,chat_id,message_id,source_hash,base_viewer,vocabulary_key,correction_key) values('{V}','{R}','{C}','{M}','{H}',true,repeat('a',64),repeat('b',64));insert into blab_qa.slots(run_id,kind,reservation_nano) values('{R}','base',12000000),('{R}','vocabulary',10000000),('{R}','correction',10000000);commit;")
def claim(kind,key,viewer=None,source=H):return f"select public.claim_hosted_qa_deep_dive_enrichment('{viewer or V}','{M}',repeat('{key}',64),'{source}','en','es',1,'{kind}',false)"
job=json.loads(val(sql('resume-job',f"update public.message_preparation_jobs set status='processing',locked_at=clock_timestamp(),lease_token=gen_random_uuid() where message_id='{M}' and viewer_id='{V}' returning json_build_object('id',id,'lease',lease_token);")));J=job['id'];L=job['lease']
nonce=val(sql('resume-base-reserve',service(f"select public.qa_reserve_worker_slot('{J}','{L}')")))
assert val(sql('resume-base-dispatch',service(dispatch('base','',nonce,f"'{J}'",f"'{L}'"))))=='t'
sql('resume-base-ready-SQL-MOCK',f"update public.message_preparation_jobs set status='ready',lease_token=null where id='{J}';insert into public.message_prepared_packages(message_id,chat_id,viewer_id,learning_language,primary_known_language,language_revision,source_version,status,translation_text) values('{M}','{C}','{V}','es','en',1,'{H}','ready','SQL MOCK ONLY');")
word=json.loads(val(sql('resume-original-word',service(claim('vocabulary','a')))));assert word['status']=='claimed';W=word['qaNonce']
assert val(sql('resume-original-failure',service(f"select public.finish_deep_dive_enrichment('{V}',repeat('a',64),'{word['lease']}',null)")))=='t'
def snapshot(name):
 return json.loads(val(sql(name,f"select json_build_object('reserved',r.reserved_nano,'state',r.state,'requests',u.day_requests,'characters',u.day_characters,'nonce',s.nonce,'dispatched',s.dispatched_at is not null) from blab_qa.runs r join blab_qa.slots s on s.run_id=r.id and s.kind='vocabulary' cross join public.translation_usage u where r.id='{R}' and u.user_id='{V}';")))
before=snapshot('resume-before');assert before==dict(reserved=22000000,state='closed',requests=1,characters=22,nonce=W,dispatched=False),before
assert json.loads(val(sql('resume-no-authorization',service(claim('vocabulary','a')))))['status']=='forbidden'
def authorize(actor=None,source=H,context='a',nonce=None,approval='20737'):
 return f"select blab_qa.authorize_resume('{R}','{actor or V}','{M}','{source}',repeat('{context}',64),'{nonce or W}','{approval}','SQL MOCK approval20737 private receipt')"
for name,q in [('actor',authorize(B)),('source',authorize(source='c'*64)),('context',authorize(context='c')),('nonce',authorize(nonce='00000000-0000-0000-0000-000000000000')),('approval',authorize(approval='20693'))]:
 assert sql('resume-denied-'+name,q,False).returncode!=0
for role in ['anon','authenticated','service_role']:
 assert sql('resume-authorizer-acl-'+role,'begin;set local role '+role+';'+authorize()+';rollback;',False).returncode!=0
for name,mutation in [('dispatched',f"update blab_qa.slots set dispatched_at=clock_timestamp() where run_id='{R}' and kind='vocabulary';"),('base',f"update public.message_preparation_jobs set status='failed' where id='{J}';"),('source-change',f"update public.messages set body='Changed source' where id='{M}';")]:
 assert sql('resume-state-denied-'+name,'begin;'+mutation+authorize()+';rollback;',False).returncode!=0
sql('resume-authorize',authorize())
assert sql('resume-repeated-authorization',authorize(),False).returncode!=0
for name,q in [('actor',claim('vocabulary','a',B)),('source',claim('vocabulary','a',source='c'*64)),('context',claim('vocabulary','c')),('known',claim('vocabulary','a').replace("'en'","'fr'"))]:
 assert json.loads(val(sql('resume-claim-denied-'+name,service(q))))['status']=='forbidden'
z=parallel('resume-parallel-claim-',claim('vocabulary','a'));got=[json.loads(val(t)) for t in z]
assert sorted(v['status'] for v in got)==['claimed']+['pending']*7,got
resumed=next(v for v in got if v['status']=='claimed');assert resumed['qaNonce']==W and resumed['lease']!=word['lease']
after=snapshot('resume-after-lease');assert after==dict(before,state='open'),after
z=parallel('resume-parallel-dispatch-',dispatch('vocabulary','a',W));assert sum(val(t)=='t' for t in z)==1
payload=json.dumps({'meaning':'SQL MOCK ONLY'})
assert val(sql('resume-word-finish',service(f"select public.finish_deep_dive_enrichment('{V}',repeat('a',64),'{resumed['lease']}', '{payload}')")))=='t'
assert json.loads(val(sql('resume-cache',service(claim('vocabulary','a')))))['status']=='cached'
correction=json.loads(val(sql('resume-correction',service(claim('correction','b')))));assert correction['status']=='claimed'
assert val(sql('resume-correction-dispatch',service(dispatch('correction','b',correction['qaNonce']))))=='t'
final=snapshot('resume-final');assert final['reserved']==32000000 and final['requests']==2 and final['characters']==44,final
assert val(sql('resume-new-failure',service(f"select public.finish_deep_dive_enrichment('{V}',repeat('b',64),'{correction['lease']}',null)")))=='t'
assert json.loads(val(sql('resume-after-new-failure',service(claim('vocabulary','a')))))['status']=='forbidden'
assert sql('resume-reauthorize-after-failure',authorize(),False).returncode!=0
(o/'RESUME-PASS.json').write_text(json.dumps({'migrationCount':141,'claimed':1,'pending':7,'wordDispatchCAS':1,'sameNonce':W==resumed['qaNonce'],'before':before,'afterLease':after,'final':final,'maximumTotalNanoUSD':79504985,'providerCalls':0,'hostedWrites':False,'mockSQLOnlyNotProviderProof':True},indent=2))
print((o/'RESUME-PASS.json').read_text())
