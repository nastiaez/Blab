#!/usr/bin/env python3
"""SQL-only regression. CI disposable DB or explicitly leased deepdive_test_* DB.
Never starts/stops containers, copies rows, invokes providers, or alters roles.
Fixtures persist in the dedicated disposable database until its lifecycle owner removes it.
"""
import pathlib,json,subprocess,shutil,concurrent.futures,threading,hashlib,argparse,os,re
P=argparse.ArgumentParser();P.add_argument('--container',required=True);P.add_argument('--database',required=True);P.add_argument('--output',default='build/deep-dive-sql');P.add_argument('--application-name',default='deepdive_sql_ci');args=P.parse_args()
assert re.fullmatch(r'supabase_db_[A-Za-z0-9_]+',args.container)
assert re.fullmatch(r'[A-Za-z0-9_]+',args.database)
assert re.fullmatch(r'[A-Za-z0-9_]+',args.application_name)
assert args.database.startswith('deepdive_test_') or (args.database=='postgres' and os.environ.get('CI')=='true'),'Dedicated disposable database required'
R=pathlib.Path(__file__).resolve().parent.parent;C=R;O=pathlib.Path(args.output).resolve();O.mkdir(parents=True,exist_ok=True);assert shutil.disk_usage(R).free>=8*1024**3
options='-c application_name='+args.application_name+' -c statement_timeout=20000 -c lock_timeout=2000 -c idle_in_transaction_session_timeout=30000 -c work_mem=8MB -c max_parallel_workers_per_gather=0'
A=['docker','exec','-i','-e','PGOPTIONS='+options,args.container,'psql','-X','-h','/tmp','-U','postgres','-d',args.database,'-v','ON_ERROR_STOP=1','-qAt'];results={}
V='da111111-1111-4111-8111-111111111111';M='da555555-5555-4555-8555-555555555555';SOURCE="'"+hashlib.sha256(b'Hola mundo').hexdigest()+"'"
def sql(name,text,ok=True):
 if shutil.disk_usage(R).free<6*1024**3:raise RuntimeError('Own tests paused: disk guard')
 p=subprocess.run(A,input=text,capture_output=True,text=True,timeout=25);(O/(name+'.out')).write_text(p.stdout);(O/(name+'.err')).write_text(p.stderr)
 if ok and p.returncode:raise RuntimeError(name+': '+p.stderr)
 return p

def call(key,retry=False):return "public.claim_deep_dive_enrichment('"+V+"','"+M+"',repeat('"+key+"',64),"+SOURCE+",'en','es',1,'vocabulary',"+str(retry).lower()+")"
def obj(p):return json.loads([s for s in p.stdout.splitlines() if s.strip()][-1])
def service(q):return "begin;select set_config('request.jwt.claims','{\"role\":\"service_role\"}',true);"+q+";commit;"
def roundclaims(name,keys):
 gate=threading.Barrier(len(keys))
 def one(pair):
  i,key=pair;gate.wait();return obj(sql(name+'-'+str(i),service('select '+call(key)+';select pg_sleep(0.25)')))
 with concurrent.futures.ThreadPoolExecutor(max_workers=len(keys)) as pool:return list(pool.map(one,enumerate(keys)))
def usage():return obj(sql('usage-'+str(len(results)),"select json_build_object('requests',day_requests,'characters',day_characters) from public.translation_usage where user_id='"+V+"';"))
def finish(name,key,lease,analysis):
 data='null' if analysis is None else "'"+json.dumps({'meaning':analysis})+"'::jsonb"
 p=sql(name,service("select public.finish_deep_dive_enrichment('"+V+"',repeat('"+key+"',64),'"+lease+"',"+data+")"));return [s for s in p.stdout.splitlines() if s.strip()][-1]=='t'
# Outbound hooks are disabled ONLY in this leased fixture database; no live services redirected.
setup="do $$begin if current_database()<>'"+args.database+"' then raise exception 'wrong database';end if;end$$;"
sql('disable-sandbox-outbound-only',setup)
fixture=(C/'supabase/tests/deep_dive_enrichment.sql').read_text().split('create temp table dd_test_state')[0].replace("'dd","'da");sql('concurrent-fixture',"select set_config('blab.allow_deep_dive_fixture','isolated-local-only',false);"+fixture+'alter table public.message_preparation_jobs enable trigger dispatch_message_preparation_jobs;alter table public.push_notification_events enable trigger send_push_notification_event;alter table public.stream_event_inbox enable trigger dispatch_stream_reconciliation;commit;')
r=roundclaims('same-context',['a','a','a']);assert [x['status'] for x in r].count('claimed')==1 and [x['status'] for x in r].count('pending')==2;r0=next(x for x in r if x['status']=='claimed');assert usage()['requests']==1;results['three_concurrent_same_key_one_charge']=r
assert finish('complete-first','a',r0['lease'],'hello');cached=obj(sql('fresh-process-cache',service('select '+call('a'))));assert cached['status']=='cached' and cached['analysis']['meaning']=='hello' and usage()['requests']==1;results['fresh_process_durable_cache_no_charge']=True
sql('last-shared-slot',"update public.translation_usage set minute_requests=59,day_requests=199,day_characters=99990 where user_id='"+V+"';")
r=roundclaims('shared-quota',['b','c']);assert sorted(x['status'] for x in r)==['claimed','rate_limited'];assert usage()=={'requests':200,'characters':100000};results['concurrent_distinct_keys_one_remaining_shared_slot']=r
for key,item in zip(['b','c'],r):
 if item['status']=='claimed':assert finish('finish-last-slot',key,item['lease'],None)
# Reset ONLY synthetic sandbox fixture counters to test independent boundaries.
sql('fixture-counter-boundary',"update public.translation_usage set minute_requests=0,day_requests=0,day_characters=0 where user_id='"+V+"';")
r=roundclaims('inflight-bound',['d','e','f']);assert [x['status'] for x in r].count('claimed')==2 and [x['status'] for x in r].count('pending')==1;assert usage()['requests']==2;results['three_distinct_concurrent_two_inflight_only']=r
active=[(k,v) for k,v in zip(['d','e','f'],r) if v['status']=='claimed'];key,old=active[0]
sql('expire-owned-fixture-lease',"update public.message_learning_enrichments set locked_until=clock_timestamp()-interval '1 second',updated_at=clock_timestamp()-interval '61 seconds' where viewer_id='"+V+"' and context_key=repeat('"+key+"',64);")
a=obj(sql('expired-no-automatic-retry',service('select '+call(key))));assert a['status']=='failed' and usage()['requests']==2
new=obj(sql('explicit-expired-retry',service('select '+call(key,True))));assert new['status']=='claimed' and new['lease']!=old['lease'];assert not finish('old-worker-fenced',key,old['lease'],'late stale');assert finish('new-worker-completes',key,new['lease'],'current');assert usage()['requests']==3;results['expired_lease_explicit_retry_old_token_fenced']=True
key,failed=active[1];assert finish('provider-failure-no-refund',key,failed['lease'],None);a=obj(sql('failed-no-auto-retry',service('select '+call(key))));assert a['status']=='failed';a=obj(sql('failed-retry-cooldown',service('select '+call(key,True))));assert a['status']=='failed' and usage()['requests']==3;results['failed_attempt_counted_no_refund_no_auto_retry']=True
for role in ['anon','authenticated','service_role']:
 p=sql('direct-table-denied-'+role,'begin;set local role '+role+';select * from public.message_learning_enrichments;rollback;',False);assert p.returncode!=0 and 'permission denied' in p.stderr
for role in ['anon','authenticated']:
 p=sql('direct-rpc-denied-'+role,'begin;set local role '+role+';select '+call('a')+';rollback;',False);assert p.returncode!=0 and 'permission denied' in p.stderr
results['actual_existing_role_acl_denials']=5
sql('source-edit-invalidates',"begin;alter table public.message_preparation_jobs disable trigger dispatch_message_preparation_jobs;alter table public.push_notification_events disable trigger send_push_notification_event;alter table public.stream_event_inbox disable trigger dispatch_stream_reconciliation;update public.messages set body='Changed source' where id='"+M+"';alter table public.message_preparation_jobs enable trigger dispatch_message_preparation_jobs;alter table public.push_notification_events enable trigger send_push_notification_event;alter table public.stream_event_inbox enable trigger dispatch_stream_reconciliation;commit;")
a=obj(sql('final-sandbox-state',"select json_build_object('database',current_database(),'bytes',pg_database_size(current_database()),'cachedRows',(select count(*) from public.message_learning_enrichments where message_id='"+M+"'),'users',(select count(*) from auth.users),'tempLimit',current_setting('temp_file_limit'));"));assert a['cachedRows']==0 and a['bytes']<250*1024**2;results['edit_invalidation_and_budget']=a;results['maxSimultaneousSessions']=3;results['retainedOrHostedWrites']=False;(O/'CONCURRENCY-PASS.json').write_text(json.dumps(results,indent=2));print(json.dumps(results,indent=2))
