#!/usr/bin/env python3
"""Full LOCAL Supabase API acceptance for owner21696. Never accepts a hosted URL."""
from pathlib import Path
import json,subprocess,urllib.request,urllib.error,time,secrets,hashlib
ROOT=Path(__file__).resolve().parents[1];Q=ROOT/'qa-artifacts/language-21696-full';STACK=Q/'stack';BASE='http://127.0.0.1:55321';CONTAINER='supabase_db_BlabLanguage21696Full'
status=json.loads(subprocess.check_output(['supabase','--workdir',str(STACK),'status','-o','json'],text=True,stderr=subprocess.DEVNULL));KEY=status.get('PUBLISHABLE_KEY') or status['ANON_KEY'];assert status['API_URL']==BASE
class NoRedirect(urllib.request.HTTPRedirectHandler):
 def redirect_request(self,*args,**kwargs):raise RuntimeError('No outbound redirects allowed')
HTTP=urllib.request.build_opener(NoRedirect);checks=[]
def check(value,label):
 assert value,label;checks.append(label)
def request(path,body=None,token=None,method=None,expected=200):
 assert path.startswith('/') and '://' not in path
 headers={'apikey':KEY,'Content-Type':'application/json'}
 if token:headers['Authorization']='Bearer '+token
 req=urllib.request.Request(BASE+path,data=json.dumps(body).encode() if body is not None else None,headers=headers,method=method)
 try:
  with HTTP.open(req,timeout=15) as r:code=r.status;raw=r.read()
 except urllib.error.HTTPError as e:code=e.code;raw=e.read()
 assert code==expected,(path,code,raw[:600].decode())
 return json.loads(raw) if raw else None

def sql(s):
 r=subprocess.run(['docker','exec','-i',CONTAINER,'psql','-U','postgres','-v','ON_ERROR_STOP=1','-X','-Atq'],input=s,text=True,capture_output=True);assert r.returncode==0,r.stderr;return r.stdout.strip()

def rpc(u,name,body):return request('/rest/v1/rpc/'+name,body,u['token'],expected=204 if name=='register_group_invitation' else 200)
def profile(u):return request('/rest/v1/profiles?id=eq.'+u['id']+'&select=id,default_learning_language,primary_known_language,interface_language,onboarding_stage',token=u['token'])[0]
def chats(u):return request('/rest/v1/chat_list?select=chat_id,my_learning,needs_practice_language_selection',token=u['token'])
def member(u,c):return next(x for x in chats(u) if x['chat_id']==c)
# This DB belongs ONLY to this test; no shared test project is touched.
assert sql('select count(*) from supabase_migrations.schema_migrations;')=='144'
check(sql("select count(*) from vault.secrets where name in ('blab_translation_worker_url','blab_push_webhook_url','stream_api_secret');")=='0','no external worker/provider credentials configured')
sql("update public.app_distribution_policy set channel='public',testing_enabled=true;")
users=[];stamp=str(int(time.time()))
for suffix,learning,known,interface in [('a','de','en','uk'),('b','ta','uk','de'),('c','ko','fi','en')]:
 password='Local-'+secrets.token_urlsafe(18)+'Aa1!'
 response=request('/auth/v1/signup',{'email':'language21696-'+stamp+'-'+suffix+'@blab.test','password':password,'data':{'name':'','onboarding_name_blank':True,'interface_language':interface}})
 u={'id':response['user']['id'],'token':response['access_token'],'learning':learning,'known':known,'interface':interface};users.append(u)
 rpc(u,'acknowledge_my_onboarding',{'p_version':1});rpc(u,'confirm_my_onboarding_name',{'p_version':1,'p_display_name':'Local '+suffix.upper()})
 request('/rest/v1/rpc/confirm_my_onboarding_languages',{'p_version':1,'p_learning_language':None,'p_known_language':known},u['token'],expected=400)
 check(profile(u)['onboarding_stage']=='language' and profile(u)['default_learning_language'] is None,'missing mandatory learning fails atomically '+suffix)
 rpc(u,'confirm_my_onboarding_languages',{'p_version':1,'p_learning_language':learning,'p_known_language':known})
 p=profile(u);check(p['default_learning_language']==learning,'saved own learning '+suffix);check(p['primary_known_language']==known,'saved own known '+suffix);check(p['interface_language']==interface,'interface unchanged '+suffix);check(p['onboarding_stage']=='complete','atomic onboarding complete '+suffix)
a,b,c=users
# Actual public wrappers, namespace checks, RLS and chat_list (not a reduced fixture).
inv=rpc(a,'create_invite',{});token=(inv[0] if isinstance(inv,list) else inv)['token']
dm=rpc(b,'claim_invite',{'invite_token':token})[0]['chat_id']
for u in [a,b]:
 row=member(u,dm);check(row['my_learning']==u['learning'],'DM participant independent '+u['learning']);check(row['needs_practice_language_selection'] is False,'DM no automatic language sheet '+u['learning'])
group=rpc(a,'create_group',{'group_name':'Local defaults'})[0]['chat_id'];invite=rpc(a,'create_group_invite',{'p_chat_id':group})[0]['token']
for u in [b,c]:
 rpc(u,'register_group_invitation',{'invite_token':invite});rpc(u,'join_group',{'invite_token':invite})
for u in users:
 row=member(u,group);check(row['my_learning']==u['learning'],'group participant independent '+u['learning']);check(row['needs_practice_language_selection'] is False,'group no automatic language sheet '+u['learning'])
# An actual authored message precedes the manual per-chat change.
request('/rest/v1/messages',{'chat_id':dm,'sender_id':b['id'],'body':'Local preserved greeting.'},b['token'],expected=201)
message_id=sql("select id from messages where chat_id='"+dm+"' and body='Local preserved greeting.' limit 1;")
check(bool(message_id),'actual local historical message persisted')
# User-controlled per-chat change must not change partner or next-chat default.
rpc(a,'set_learning_language',{'p_chat_id':dm,'p_learning_language':'fr'})
check(member(a,dm)['my_learning']=='fr','manual DM override available');check(sql("select body from messages where id='"+message_id+"';")=='Local preserved greeting.','authored history unchanged after manual override');check(sql("select learning_language from chat_language_timeline where chat_id='"+dm+"' and user_id='"+a['id']+"' and revision=1;")=='de','original learning era unchanged');check(member(b,dm)['my_learning']=='ta','partner preserved after override');check(profile(a)['default_learning_language']=='de','manual override leaves account default');check(member(a,group)['my_learning']=='de','other group unaffected')
rpc(b,'claim_invite',{'invite_token':token});check(member(a,dm)['my_learning']=='fr','repeat DM invite preserves explicit override')
nextgroup=rpc(a,'create_group',{'group_name':'Local next defaults'})[0]['chat_id'];check(member(a,nextgroup)['my_learning']=='de','next group uses saved default not previous chat override');check(member(a,nextgroup)['needs_practice_language_selection'] is False,'next group no picker')
# Attempting to write the protected field cannot mutate either identity.
request('/rest/v1/profiles?id=eq.'+b['id'],{'default_learning_language':'fr'},a['token'],'PATCH',403)
check(profile(b)['default_learning_language']=='ta','other account default unchanged');check(profile(a)['interface_language']=='uk','interface still independent after chats')
new=rpc(a,'create_invite',{});token2=(new[0] if isinstance(new,list) else new)['token'];second=rpc(c,'claim_invite',{'invite_token':token2})[0]['chat_id'];check(member(a,second)['my_learning']=='de' and member(c,second)['my_learning']=='ko','next DM restores each saved default')
check(all(not r['needs_practice_language_selection'] for u in users for r in chats(u)),'all new current-public-wrapper rows configured/no automatic picker')
# Explicitly separate legacy/defaultless contract: keep safe chooser, no silent migration.
legacy_response=request('/auth/v1/signup',{'email':'language21696-'+stamp+'-legacy@blab.test','password':'Local-'+secrets.token_urlsafe(18)+'Aa1!','data':{'name':'','onboarding_name_blank':True}})
legacy={'id':legacy_response['user']['id'],'token':legacy_response['access_token']}
rpc(legacy,'acknowledge_my_onboarding',{'p_version':1});rpc(legacy,'confirm_my_onboarding_name',{'p_version':1,'p_display_name':'Local legacy'})
rpc(legacy,'confirm_my_onboarding_language',{'p_version':1,'p_language':'it'})
check(profile(legacy)['default_learning_language'] is None,'legacy default remains unset')
request('/rest/v1/rpc/confirm_my_onboarding_languages',{'p_version':1,'p_learning_language':'de','p_known_language':'it'},legacy['token'],expected=400)
check(profile(legacy)['default_learning_language'] is None,'no silent migration of completed legacy account')
legacy_dm=rpc(legacy,'claim_invite',{'invite_token':token})[0]['chat_id']
check(member(legacy,legacy_dm)['needs_practice_language_selection'] is True,'legacy required-selection fallback retained')
check(member(a,legacy_dm)['my_learning']=='de' and member(a,legacy_dm)['needs_practice_language_selection'] is False,'legacy peer does not unset configured participant')
rpc(legacy,'set_learning_language',{'p_chat_id':legacy_dm,'p_learning_language':'pl'})
check(member(legacy,legacy_dm)['my_learning']=='pl' and member(legacy,legacy_dm)['needs_practice_language_selection'] is False,'legacy manual per-chat selection works')
check(profile(legacy)['default_learning_language'] is None,'legacy per-chat choice not invented as global default')
result={'state':'FULL_LOCAL_SUPABASE_API_PASS','migrations':144,'assertions':len(checks),'checks':checks,'users':'3 synthetic LOCAL accounts; tokens/passwords memory only','functions':'real GoTrue signup+current onboarding RPC/public DM claim/group create/invite/register/join/manual setting/chat_list RLS','backend':'http://127.0.0.1:55321 ONLY; no remote writes/deployment','native':'not exercised by API test','historyMessageId':message_id}
(Q/'api-receipt.json').write_text(json.dumps(result,indent=2));print(json.dumps({'state':result['state'],'assertions':len(checks),'migrations':144}))
