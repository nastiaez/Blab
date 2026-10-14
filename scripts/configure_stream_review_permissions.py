"""Seal all channel types in the isolated development app; never production."""
import base64
import hashlib
import hmac
import json
import time
import urllib.request
import urllib.error
from pathlib import Path

def main():
    credential=json.loads(Path('/Users/aswin/clawd/secrets/blab-stream-review.json').read_text())
    if str(credential.get('appId'))!='1731706' or credential.get('mode')!='development':
        raise SystemExit('Refusing non-review application')
    def encode(value):return base64.urlsafe_b64encode(json.dumps(value,separators=(',',':')).encode()).decode().rstrip('=')
    def call(path,body=None,user=None,method=None):
        now=int(time.time())
        unsigned=encode({'alg':'HS256','typ':'JWT'})+'.'+encode({'server':True} if user is None else {'user_id':user,'iat':now-2,'exp':now+3600})
        token=unsigned+'.'+base64.urlsafe_b64encode(hmac.new(credential['apiSecret'].encode(),unsigned.encode(),hashlib.sha256).digest()).decode().rstrip('=')
        request=urllib.request.Request('https://chat.stream-io-api.com/'+path+'?api_key='+credential['apiKey'],data=None if body is None else json.dumps(body).encode(),headers={'Authorization':token,'Stream-Auth-Type':'jwt','Content-Type':'application/json'},method=method)
        try:
            with urllib.request.urlopen(request,timeout=15) as response:return response.status,json.load(response)
        except urllib.error.HTTPError as error:return error.code,json.load(error)
    code,before=call('channeltypes')
    if code!=200 or not isinstance(before.get('channel_types'),dict):raise SystemExit('Inspection failed')
    types=before['channel_types']
    root=Path('docs/qa/2026-10-14-stream-delivery')
    backup=root/'vendor-channeltype-grants-before.json'
    if not backup.exists():backup.write_text(json.dumps({'app':'1731706','channel_types':{name:data.get('grants',{}) for name,data in types.items()}},indent=2)+'\n')
    changes=[]
    for name,data in types.items():
        expected={'user':[],'guest':[],'anonymous':[],
                  'channel_member':['read-channel','read-channel-members'] if name=='blab' else []}
        if all(data.get('grants',{}).get(role)==grants for role,grants in expected.items()):continue
        code,_=call('channeltypes/'+name,{'grants':expected},method='PUT')
        if not 200<=code<300:raise SystemExit('Permission update failed for '+name)
        changes.append(name)
    code,after=call('channeltypes')
    if code!=200:raise SystemExit('Verification inspection failed')
    checks={}
    user='00000000-0000-4000-8000-00000000000a'
    partner='00000000-0000-4000-8000-00000000000b'
    outsider='00000000-0000-4000-8000-000000000903'
    chat='71000000-0000-4000-8000-000000000001'
    for name,data in after['channel_types'].items():
        checks[name+'_normal_grants_sealed']=all(data.get('grants',{}).get(role)==[] for role in ['user','guest','anonymous'])
        code,_=call('channels/'+name+'/unauthorized-blab-review/query',{'data':{'members':[user,partner]},'state':False,'watch':False},user=user)
        checks[name+'_client_cannot_create_channel']=code==403
    code,_=call('channels/blab/'+chat+'/query',{'state':True,'watch':False},user=partner)
    checks['authorized_member_reads']=200<=code<300
    code,_=call('channels/blab/'+chat+'/query',{'state':True,'watch':False},user=outsider)
    checks['nonmember_cannot_read']=code==403
    code,_=call('channels/blab/'+chat+'/message',{'message':{'text':'Client authorization bypass must fail'}},user=user)
    checks['direct_client_send_denied']=code==403
    result={'app':'1731706','scope':'Live final channel-type permissions in development review app; no production users/history. Server commands remain authoritative.',
            'changed_types':changes,'checks':checks,
            'references':['https://getstream.io/chat/docs/node/chat-permission-policies/','https://getstream.io/chat/docs/php/channel-features/']}
    (root/'vendor-final-permission-checks.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'changed_types':changes,'passed':sum(checks.values()),'total':len(checks)}))
    if not all(checks.values()):raise SystemExit(1)

if __name__=='__main__':main()
