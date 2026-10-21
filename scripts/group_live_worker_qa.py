#!/usr/bin/env python3
"""Bounded paid local acceptance; never drains the retained local job backlog."""
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import subprocess
import time
import urllib.request
import uuid

api = runpy.run_path('scripts/group_live_learning_qa.py')
call = api['call']
status = api['status']
OUT = Path('docs/qa/2026-10-21-group-live-ai')
OUT.mkdir(parents=True, exist_ok=True)
scratch = Path('build/group-live-20261021')
scratch.mkdir(parents=True, exist_ok=True)
key_file = Path('../Blab/supabase/.env.local')
match = re.search(r'(?m)^OPEN_ROUTER_KEY=[\"\']?([^\n\"\']+)', key_file.read_text())
assert match, 'Existing Blab app-testing key required'
provider_key = match[1].strip()


def credits():
    request = urllib.request.Request('https://openrouter.ai/api/v1/credits',
        headers={'Authorization': 'Bearer ' + provider_key})
    data = json.load(urllib.request.urlopen(request, timeout=15))['data']
    return data['total_credits'] - data['total_usage']


def sql(text):
    return subprocess.check_output(['docker', 'exec', '-i',
        'supabase_db_Blab_Groups_20261019', 'psql', '-X', '-qAt',
        '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres'],
        input=text.encode()).decode().strip()


def process(message, name, expected_viewers=3, only_viewer=None):
    uuid.UUID(message)
    excluded = f"message_id<>'{message}'::uuid"
    if only_viewer:
        uuid.UUID(only_viewer)
        excluded += f" or viewer_id<>'{only_viewer}'::uuid"
    # Real claim function, confined to this fresh message. Defer older jobs only
    # within this transaction and restore their timestamps before committing.
    leases = sql(f"""begin;
select set_config('request.jwt.claims','{{"role":"service_role"}}',true) is not null \\g /dev/null
create temp table held as select id,available_at from message_preparation_jobs
 where ({excluded}) and status='queued';
update message_preparation_jobs set available_at=clock_timestamp()+interval '1 day'
 where id in(select id from held);
select coalesce(json_agg(j),'[]') from claim_message_preparation_jobs_for_worker(1) j;
update message_preparation_jobs j set available_at=h.available_at from held h where h.id=j.id;
commit;""")
    jobs = json.loads(leases)
    assert len(jobs) == expected_viewers, jobs
    assert all(j['message_id'] == message for j in jobs)
    inp, metrics = scratch / (name+'-leases.json'), OUT / (name+'-metrics.json')
    inp.write_text(json.dumps(jobs))
    env = dict(os.environ, QA_SUPABASE_URL=api['BASE'],
        QA_SERVICE_ROLE=status['SERVICE_ROLE_KEY'], OPEN_ROUTER_KEY=provider_key,
        BLAB_ENV='local')
    env.pop('OPENAI_API_KEY', None)
    started = time.monotonic()
    subprocess.run(['deno','run','--allow-env','--allow-net','--allow-read',
        '--allow-write='+str(OUT), 'scripts/group_live_worker_qa.ts',
        str(inp), str(metrics)], env=env, check=True, timeout=90)
    scope = f"message_id='{message}'"
    if only_viewer:
        scope += f" and viewer_id='{only_viewer}'"
    states = json.loads(sql(f"select json_agg(json_build_object('status',status,'error',last_error)) from message_preparation_jobs where {scope};"))
    assert all(j['status'] == 'ready' for j in states), states
    measured = json.loads(metrics.read_text())['metrics']
    assert len(measured) == 1 and measured[0]['status'] == 200, measured
    return {'message':message, 'seconds':round(time.monotonic()-started,2),
        'provider_calls':len(measured), 'metrics':measured}


def main():
    before = credits()
    assert before > .25, 'Insufficient existing app-testing balance'
    accounts, originals, result = {}, {}, {'balance_before':before}
    try:
        for name in ['alice','bob','carol']:
            session=call('/auth/v1/token?grant_type=password',
                {'email':name+'@blab.test','password':'Blab-local-123!'})
            token, uid = session['access_token'],session['user']['id']
            accounts[name]=(token,uid)
            originals[name]=call('/rest/v1/profiles?id=eq.'+uid+
                '&select=interface_language,known_languages,primary_known_language',token=token)[0]
        settings={'alice':('en',['uk'],'uk','en'),
                  'bob':('es',['en'],'en','de'),
                  'carol':('de',['en'],'en','de')}
        for name,(ui,known,primary,_) in settings.items():
            token,uid=accounts[name]
            call('/rest/v1/rpc/update_my_interface_language',{'p_interface_language':ui},token)
            call('/rest/v1/profiles?id=eq.'+uid,{'known_languages':known,
                'primary_known_language':primary},token,'PATCH')
        alice=accounts['alice'][0]
        group=call('/rest/v1/rpc/create_group',{'group_name':'Live group translation'},alice)[0]['chat_id']
        invite=call('/rest/v1/rpc/create_group_invite',{'p_chat_id':group},alice)[0]['token']
        for name in ['bob','carol']:
            call('/rest/v1/rpc/join_group',{'invite_token':invite},accounts[name][0])
        for name,(_,_,_,learning) in settings.items():
            token,uid=accounts[name]
            call('/rest/v1/rpc/set_learning_language',{'p_chat_id':group,
                'p_learning_language':learning},token)
            call('/rest/v1/chat_members?chat_id=eq.'+group+'&user_id=eq.'+uid,
                {'mode':'practice'},token,'PATCH')
        message=call('/rest/v1/messages',{'chat_id':group,'sender_id':accounts['alice'][1],
            'body':'Yesterday I go to the park.'},alice)[0]['id']
        result.update(group=group,settings=settings,key_fingerprint=hashlib.sha256(provider_key.encode()).hexdigest()[:12])
        result['shared']=process(message,'shared')
        outputs={}
        for name,(token,uid) in accounts.items():
            rows=call('/rest/v1/message_prepared_packages?message_id=eq.'+message,token=token)
            assert len(rows)==1 and rows[0]['viewer_id']==uid, rows
            outputs[name]=rows[0]
        assert outputs['bob']['translation_text']==outputs['carol']['translation_text']
        assert outputs['alice']['aid_mode']=='correction',outputs['alice']
        assert all(outputs[n]['explanation'] is None and outputs[n]['aid_mode']!='correction'
            for n in ['bob','carol'])
        # Cached UI-independent reads must not enqueue or regenerate work.
        for name,(token,_) in accounts.items():
            cached=call('/rest/v1/rpc/request_message_translation_variant',{'p_message_id':message},token)
            assert cached['status']=='cached',cached
        call('/rest/v1/rpc/update_my_interface_language',{'p_interface_language':'uk'},accounts['bob'][0])
        cached=call('/rest/v1/rpc/request_message_translation_variant',{'p_message_id':message},accounts['bob'][0])
        assert cached['translation']==outputs['bob']['translation_text']
        result['shared']['outputs']=outputs
        # One genuinely asymmetric viewer; still one bounded provider request.
        token,uid=accounts['carol']
        call('/rest/v1/profiles?id=eq.'+uid,{'known_languages':['uk'],'primary_known_language':'uk'},token,'PATCH')
        call('/rest/v1/rpc/set_learning_language',{'p_chat_id':group,'p_learning_language':'es'},token)
        message2=call('/rest/v1/messages',{'chat_id':group,'sender_id':accounts['bob'][1],
            'body':'We will meet at the station tomorrow at ten.'},accounts['bob'][0])[0]['id']
        result['asymmetric']=process(message2,'asymmetric')
        result['asymmetric']['outputs']={name:call('/rest/v1/message_prepared_packages?message_id=eq.'+message2,token=t)[0]
            for name,(t,_) in accounts.items()}
        for name,expected in [('alice','en'),('bob','de'),('carol','es')]:
            assert result['asymmetric']['outputs'][name]['learning_language']==expected
        # Latest join fences real completed provider results, not fake caches.
        bob=accounts['bob'][0]
        call('/rest/v1/rpc/leave_group',{'p_chat_id':group},bob)
        call('/rest/v1/rpc/join_group',{'invite_token':invite},bob)
        call('/rest/v1/rpc/set_learning_language',{'p_chat_id':group,'p_learning_language':'de'},bob)
        for mid in [message,message2]:
            cached=call('/rest/v1/rpc/request_message_translation_variant',{'p_message_id':mid},bob)
            assert cached['status']=='forbidden',cached
        retained=call('/rest/v1/messages?chat_id=eq.'+group+'&select=id,body',token=bob)
        assert {message,message2}<={m['id'] for m in retained}
        result['rejoin']={'originals_readable':True,'old_ai_forbidden':True}
        call('/rest/v1/chat_members?chat_id=eq.'+group+'&user_id=eq.'+accounts['bob'][1],
            {'mode':'practice'},bob,'PATCH')
        message3=call('/rest/v1/messages',{'chat_id':group,'sender_id':accounts['alice'][1],
            'body':'Please bring two apples tomorrow.'},alice)[0]['id']
        result['after_rejoin']=process(message3,'after-rejoin')
        result['after_rejoin']['outputs']={name:call('/rest/v1/message_prepared_packages?message_id=eq.'+message3,token=t)[0]
            for name,(t,_) in accounts.items()}
        call('/rest/v1/rpc/request_message_translation_variant',{'p_message_id':message},accounts['carol'][0])
        result['known_language_refresh']=process(message,'known-language-refresh',
            expected_viewers=1,only_viewer=accounts['carol'][1])
        result['balance_after']=credits()
        result['account_delta']=before-result['balance_after']
        result['provider_reported_cost']=sum(metric['usage']['cost']
            for case in ['shared','asymmetric','after_rejoin','known_language_refresh'] for metric in result[case]['metrics'])
        result['status']='PASS'
        (OUT/'receipt.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
        (scratch/'fixture.json').write_text(json.dumps({'group':group,'message':message,'message2':message2}))
        print('PASS real group worker: three fresh messages plus one preference refresh, four provider calls; private corrections, shared/asymmetric outputs, cache and rejoin checks.')
        print('Account delta:',result['account_delta'])
    finally:
        for name,original in originals.items():
            token,uid=accounts[name]
            call('/rest/v1/rpc/update_my_interface_language',{'p_interface_language':original['interface_language']},token)
            call('/rest/v1/profiles?id=eq.'+uid,{k:v for k,v in original.items() if k!='interface_language'},token,'PATCH')
        print('Local profile preferences restored.')


if __name__=='__main__':
    main()
