#!/usr/bin/env python3
"""Live local group-language API proof; no agent auth or production endpoints."""
import json
import subprocess
import time
import urllib.error
import urllib.request
import uuid

BASE = 'http://127.0.0.1:57321'
status = json.loads(subprocess.check_output(
    ['supabase', 'status', '--workdir', 'build/group-backend', '-o', 'json'],
    stderr=subprocess.DEVNULL))
KEY = status.get('PUBLISHABLE_KEY') or status['ANON_KEY']


def call(path, payload=None, token=None, method=None):
    headers = {'apikey': KEY, 'Content-Type': 'application/json',
               'Prefer': 'return=representation'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    request = urllib.request.Request(BASE + path,
        data=None if payload is None else json.dumps(payload).encode(),
        headers=headers, method=method or ('GET' if payload is None else 'POST'))
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            body = response.read()
            return json.loads(body) if body else None
    except urllib.error.HTTPError as error:
        body = error.read().decode()
        raise RuntimeError(f'Local endpoint {path.split("?")[0]} returned {error.code}: {body}') from None


def main():
    accounts = {}
    originals = {}
    try:
        for name in ['alice', 'bob', 'carol']:
            session = call('/auth/v1/token?grant_type=password',
                {'email': name+'@blab.test', 'password': 'Blab-local-123!'})
            token, uid = session['access_token'], session['user']['id']
            accounts[name] = (token, uid)
            originals[name] = call('/rest/v1/profiles?id=eq.'+uid+
                '&select=interface_language,known_languages,primary_known_language', token=token)[0]
        preferences = {'alice': ('en', ['uk'], 'uk', 'en'),
                       'bob': ('es', ['en'], 'en', 'de'),
                       'carol': ('de', ['uk'], 'uk', 'es')}
        for name, (ui, known, primary, learning) in preferences.items():
            token, uid = accounts[name]
            call('/rest/v1/rpc/update_my_interface_language', {'p_interface_language':ui}, token)
            call('/rest/v1/profiles?id=eq.'+uid, {
                'known_languages':known, 'primary_known_language':primary}, token, 'PATCH')
        alice, _ = accounts['alice']
        group = call('/rest/v1/rpc/create_group', {'group_name':'Live language QA'}, alice)[0]['chat_id']
        invite = call('/rest/v1/rpc/create_group_invite', {'p_chat_id':group}, alice)[0]['token']
        for name in ['bob', 'carol']:
            call('/rest/v1/rpc/join_group', {'invite_token':invite}, accounts[name][0])
        for name, (_, _, _, learning) in preferences.items():
            token, uid = accounts[name]
            call('/rest/v1/rpc/set_learning_language',
                {'p_chat_id':group, 'p_learning_language':learning}, token)
            call('/rest/v1/chat_members?chat_id=eq.'+group+'&user_id=eq.'+uid,
                {'mode':'practice'}, token, 'PATCH')
        message = call('/rest/v1/messages', {'chat_id':group,
            'sender_id':accounts['alice'][1], 'body':'Yesterday I go to the park.'}, alice)[0]['id']
        # Isolate only this fresh message from the unconfigured local queue;
        # direct provider proof must not compete with a preparation-job owner.
        uuid.UUID(message)
        subprocess.run(['docker','exec','supabase_db_Blab_Groups_20261019',
            'psql','-X','-v','ON_ERROR_STOP=1','-U','postgres','-d','postgres','-c',
            f"delete from public.message_preparation_jobs where message_id='{message}'::uuid"],
            check=True,stdout=subprocess.DEVNULL)
        results = {}
        for name, (_, _, primary, learning) in preferences.items():
            start = time.monotonic()
            result = call('/functions/v1/translate-message', {'messageId':message}, accounts[name][0])
            assert result['targetLang'] == learning, result
            assert result['interfaceLang'] == primary, result
            assert result.get('translation'), result
            results[name] = result
            print(f'PASS live {name}: Practice={learning}, Known={primary}, UI={preferences[name][0]}, mode={result.get("mode")}, {time.monotonic()-start:.1f}s', flush=True)
        # Interface Language is not a learning-output selector.
        token, uid = accounts['bob']
        call('/rest/v1/rpc/update_my_interface_language', {'p_interface_language':'de'}, token)
        after = call('/functions/v1/translate-message', {'messageId':message}, token)
        assert after['targetLang'] == 'de' and after['interfaceLang'] == 'en'
        assert after['translation'] == results['bob']['translation']
        print('PASS: Interface Language change preserves the completed learning output.', flush=True)
        # Query the private store without the client-side viewer filter.
        for name, (token, uid) in accounts.items():
            rows = call('/rest/v1/message_prepared_packages?message_id=eq.'+message+
                '&select=viewer_id', token=token)
            assert all(row['viewer_id'] == uid for row in rows), rows
        print('PASS: participants cannot read each other’s prepared learning packages.', flush=True)
        print(json.dumps({'group':group, 'message':message, 'result_modes':
            {name:r.get('mode') for name,r in results.items()}}, ensure_ascii=False))
    finally:
        for name, original in originals.items():
            token, uid = accounts[name]
            call('/rest/v1/rpc/update_my_interface_language',
                {'p_interface_language':original['interface_language']}, token)
            call('/rest/v1/profiles?id=eq.'+uid,
                {k:v for k,v in original.items() if k!='interface_language'}, token, 'PATCH')
        print('Original local account preferences restored.', flush=True)


if __name__ == '__main__':
    main()
