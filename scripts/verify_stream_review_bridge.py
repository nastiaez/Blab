#!/usr/bin/env python3
"""Local Blab authentication + real isolated Stream exchange, no real users."""
import json
import hashlib
import hmac
import os
from pathlib import Path
import urllib.request
import urllib.error

STATUS = Path('/tmp/blab-stream-local-status.json')
IDENTITIES = Path('/tmp/blab-stream-review-identities.json')
CHAT = '71000000-0000-4000-8000-000000000001'
MESSAGE = '71000000-0000-4000-8000-000000000002'
REQUEST = '71000000-0000-4000-8000-000000000003'


def main():
    status = json.loads(STATUS.read_text())
    if status['API_URL'] != 'http://127.0.0.1:54441':
        raise SystemExit('Refusing non-owned local backend')
    credentials = json.loads(Path('/Users/aswin/clawd/secrets/blab-stream-review.json').read_text())
    if str(credentials.get('appId')) != '1731706' or credentials.get('mode') != 'development':
        raise SystemExit('Refusing non-review vendor app')
    root = status['API_URL']
    key = status.get('ANON_KEY') or status['PUBLISHABLE_KEY']
    identities = json.loads(IDENTITIES.read_text()) if IDENTITIES.exists() else {}
    checks = {}

    def call(path, payload=None, bearer=None, headers=None, method=None, external=False):
        body = payload if isinstance(payload, bytes) else None if payload is None else json.dumps(payload, separators=(',', ':')).encode()
        req = urllib.request.Request(path if external else root + path, data=body,
            headers={'Content-Type': 'application/json', **({} if external else {'apikey': key}),
                     **({'Authorization': 'Bearer ' + bearer} if bearer else {}), **(headers or {})}, method=method)
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                return response.status, json.load(response)
        except urllib.error.HTTPError as error:
            return error.code, json.load(error)

    for name in ['alice', 'bob']:
        if name not in identities:
            code, account = call('/auth/v1/token?grant_type=password', {'email': name + '@blab.test', 'password': 'Blab-local-123!'})
            if code != 200:
                raise SystemExit('Local test authentication unavailable')
            identities[name] = {'userId': account['user']['id'], 'supabaseToken': account['access_token']}
        code, token = call('/functions/v1/stream-token', {'userId': 'forged-identity'}, identities[name]['supabaseToken'])
        checks[name + '_token_identity_bound'] = code == 200 and token.get('userId') == identities[name]['userId']
        if code != 200:
            raise SystemExit('Stream token unavailable')
        identities[name].update({'streamToken': token['token'], 'apiKey': token['apiKey']})
        IDENTITIES.write_text(json.dumps(identities)); os.chmod(IDENTITIES, 0o600)
        code, channel = call('/functions/v1/stream-channel', {'chatId': CHAT}, identities[name]['supabaseToken'])
        checks[name + '_authorized_channel'] = code == 200 and channel.get('channelId') == CHAT
    alice, bob = identities['alice'], identities['bob']
    vendor = 'https://chat.stream-io-api.com/channels/blab/' + CHAT
    vendor_headers = {'Authorization': alice['streamToken'], 'Stream-Auth-Type': 'jwt'}
    code, _ = call(vendor + '/message?api_key=' + credentials['apiKey'], {'message': {'text': 'Client bypass must fail'}}, headers=vendor_headers, external=True)
    checks['client_cannot_bypass_blabs_authorization'] = code == 403
    payload = {'requestId': REQUEST, 'chatId': CHAT, 'messageId': MESSAGE, 'action': 'send', 'body': 'Review bridge original'}
    code, sent = call('/functions/v1/stream-message', payload, alice['supabaseToken'])
    checks['authenticated_send_acknowledged'] = code == 200 and sent.get('id') == MESSAGE
    code, repeated = call('/functions/v1/stream-message', payload, alice['supabaseToken'])
    checks['same_command_reuses_acknowledgment'] = code == 200 and repeated == sent
    code, received = call(vendor + '/query?api_key=' + credentials['apiKey'], {'state': True, 'watch': False, 'messages': {'limit': 100}},
                          headers={'Authorization': bob['streamToken'], 'Stream-Auth-Type': 'jwt'}, external=True)
    matched = [m for m in received.get('messages', []) if m['id'] == MESSAGE]
    checks['recipient_has_one_original'] = 200 <= code < 300 and len(matched) == 1 and matched[0].get('text') == payload['body']
    # This is a genuine signed event fixture, not proof of public vendor dispatch.
    if matched:
        event = json.dumps({'type': 'message.new', 'cid': 'blab:' + CHAT, 'created_at': matched[0]['created_at'], 'message': {'id': MESSAGE}}, separators=(',', ':')).encode()
        signature = hmac.new(credentials['apiSecret'].encode(), event, hashlib.sha256).hexdigest()
        headers = {'X-Api-Key': credentials['apiKey'], 'X-Signature': signature, 'X-Webhook-Id': 'blab-review-bridge-message-1'}
        code, queued = call('/functions/v1/stream-events', event, headers=headers)
        checks['signed_event_durably_accepted'] = code == 200 and queued.get('state') in ['queued', 'duplicate']
        code, duplicate = call('/functions/v1/stream-events', event, headers=headers)
        checks['signed_event_retry_deduplicated'] = code == 200 and duplicate.get('state') == 'duplicate'
        code, outcome = call('/functions/v1/reconcile-stream-events', {}, status['SERVICE_ROLE_KEY'])
        checks['canonical_reconciliation_runs'] = code == 200 and all(x.get('state') == 'done' for x in outcome.get('outcomes', []))
        code, projection = call('/rest/v1/messages?select=id,body&id=eq.' + MESSAGE, bearer=bob['supabaseToken'])
        checks['private_learning_source_matches_original'] = code == 200 and len(projection) == 1 and projection[0]['body'] == payload['body']
    result = {'isolated_app': '1731706', 'local_backend': 'Blab_Stream_20261014', 'checks': checks,
              'scope': 'Authenticated local Blab endpoints and real Stream exchange with signed event fixture. Not public webhook dispatch, live AI, push or Android acceptance.'}
    Path('docs/qa/2026-10-14-stream-delivery/local-bridge-checks.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'passed': sum(checks.values()), 'total': len(checks), 'checks': checks}))
    raise SystemExit(0 if all(checks.values()) else 1)

if __name__ == '__main__':
    main()
