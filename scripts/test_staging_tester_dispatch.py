#!/usr/bin/env python3
"""CI disposable SQL mocks ONLY. Never provider proof or hosted execution."""
import argparse,concurrent.futures,hashlib,json,os,pathlib,subprocess
p=argparse.ArgumentParser();p.add_argument('--container',required=True);p.add_argument('--output',required=True);a=p.parse_args()
if os.environ.get('CI')!='true':p.error('CI disposable container only')
o=pathlib.Path(a.output);o.mkdir(parents=True,exist_ok=True)
def sql(name,q):
 r=subprocess.run(['docker','exec','-i','-e','PGOPTIONS=-c blab.allow_deep_dive_fixture=isolated-local-only',a.container,'psql','-X','-qAt','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],input=q,text=True,capture_output=True);(o/(name+'.out')).write_text(r.stdout);(o/(name+'.err')).write_text(r.stderr);assert r.returncode==0,(name,r.stderr);return r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ''
def svc(q):return "begin;set local request.jwt.claims='{\"role\":\"service_role\"}';"+q+';commit;'
src=pathlib.Path('supabase/tests/staging_tester_deep_dive.sql').read_text();fixture=src[:src.index('create temp table e2_test_state')].replace('e2','e3')
V='e3111111-1111-4111-8111-111111111111';M='e3555555-5555-4555-8555-555555555555';H=hashlib.sha256(b'Hola mundo').hexdigest();K='a'*64;REV='c'*40
sql('normal-parallel-fixture',fixture+f"update public.app_distribution_policy set channel='test',testing_enabled=true,testing_expires_at=null;insert into public.test_app_members(user_id) values('{V}');select blab_staging.activate('{REV}','OFFLINE MOCK parallel ordinary release proof');commit;")
base=int(sql('normal-qa-budget-before','select coalesce(sum(reserved_nano),0) from blab_qa.runs;'))
claim=f"select public.claim_hosted_deep_dive_enrichment('{V}','{M}','{K}','{H}','en','es',1,'vocabulary','{REV}',false)"
def parallel(label,q):
 with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:return list(pool.map(lambda i:sql(label+str(i),svc(q)),range(8)))
x=[json.loads(t) for t in parallel('normal-parallel-claim-',claim)];assert sorted(t['status'] for t in x)==['claimed']+['pending']*7,x
v=next(t for t in x if t['status']=='claimed');assert v['admissionClass']=='tester' and 'qaNonce' not in v;L=v['lease']
dispatch=f"select public.staging_deep_dive_dispatch('{V}','{M}','{K}','{H}','en','es',1,'vocabulary','{REV}','{L}')"
y=parallel('normal-parallel-dispatch-',dispatch);assert y.count('t')==1 and y.count('f')==7,y
counts=json.loads(sql('normal-parallel-snapshot',f"select json_build_object('requests',day_requests,'characters',day_characters,'dispatches',(select count(*) from blab_staging.dispatches where viewer_id='{V}'),'qaReserved',(select coalesce(sum(reserved_nano),0) from blab_qa.runs)) from public.translation_usage where user_id='{V}';"));assert counts=={'requests':1,'characters':10,'dispatches':1,'qaReserved':base},counts
assert sql('normal-mock-finish',svc(f"select public.finish_deep_dive_enrichment('{V}','{K}','{L}','{{\"meaning\":\"OFFLINE SQL MOCK\"}}')"))=='t'
assert json.loads(sql('normal-cache',svc(claim)))['status']=='cached'
sql('normal-deactivate',"select blab_staging.deactivate(id,'OFFLINE MOCK final deactivation proof') from blab_staging.rollouts where deactivated_at is null;")
assert json.loads(sql('normal-closed',svc(claim)))['status']=='forbidden'
assert int(sql('normal-quota-after',f"select day_requests from public.translation_usage where user_id='{V}';"))==1
proof={'parallelClaimed':1,'parallelPending':7,'parallelDispatchCAS':1,'requests':1,'characters':10,'qaReservedUnchanged':True,'cachedUncharged':True,'deactivatedDenied':True,'providerCalls':0,'hostedWrites':False,'mockSQLOnlyNotProviderProof':True};(o/'STAGING-PASS.json').write_text(json.dumps(proof,indent=2));print(json.dumps(proof))
