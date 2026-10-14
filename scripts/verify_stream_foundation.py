#!/usr/bin/env python3
"""Isolated Stream review fixture proof. Never accepts production credentials."""
import base64
import hashlib
import hmac
import json
from pathlib import Path
import time
import urllib.error
import urllib.request

CREDENTIALS = Path('/Users/aswin/clawd/secrets/blab-stream-review.json')
OUTPUT = Path(__file__).resolve().parents[1] / 'docs/qa/2026-10-14-stream-delivery/vendor-foundation-checks.json'
A = '00000000-0000-4000-8000-000000000901'
B = '00000000-0000-4000-8000-000000000902'
OUTSIDER = '00000000-0000-4000-8000-000000000903'
CHANNEL = '00000000-0000-4000-8000-000000000904'
MESSAGE = '00000000-0000-4000-8000-000000000905'

def main():
    credentials = json.loads(CREDENTIALS.read_text())
    if credentials.get('appId') != '1731706' and credentials.get('appId') != 1731706:
        raise SystemExit('Refusing non-review application')
    if credentials.get('mode') != 'development':
        raise SystemExit('Refusing non-development application')

    def encode(value):
        return base64.urlsafe_b64encode(json.dumps(value, separators=(',', ':')).encode()).decode().rstrip('=')

    def request(path, body=None, user=None):
        now = int(time.time())
        claims = {'server': True} if user is None else {'user_id': user, 'iat': now - 2, 'exp': now + 3600}
        unsigned = encode({'alg': 'HS256', 'typ': 'JWT'}) + '.' + encode(claims)
        signature = hmac.new(credentials['apiSecret'].encode(), unsigned.encode(), hashlib.sha256).digest()
        token = unsigned + '.' + base64.urlsafe_b64encode(signature).decode().rstrip('=')
        req = urllib.request.Request(
            'https://chat.stream-io-api.com/' + path + '?api_key=' + credentials['apiKey'],
            data=None if body is None else json.dumps(body).encode(),
            headers={'Authorization': token, 'Stream-Auth-Type': 'jwt', 'Content-Type': 'application/json'},
        )
        try:
            with urllib.request.urlopen(req, timeout=15) as response:
                return response.status, json.load(response)
        except urllib.error.HTTPError as error:
            return error.code, json.load(error)

    checks = {}
    status, _ = request('users', {'users': {uid: {'id': uid, 'role': 'user', 'name': 'Blab isolated fixture'} for uid in [A, B, OUTSIDER]}})
    checks['server_provision_users'] = 200 <= status < 300
    path = 'channels/blab/' + CHANNEL
    status, _ = request(path + '/query', {'data': {'members': [A, B], 'created_by_id': A}, 'state': False, 'watch': False})
    checks['server_provision_channel'] = 200 <= status < 300
    # Inspect before retrying an already accepted fixture message.
    status, channel = request(path + '/query', {'state': True, 'watch': False, 'messages': {'limit': 100}}, B)
    existing = next((m for m in channel.get('messages', []) if m['id'] == MESSAGE), None)
    if existing is None:
        status, sent = request(path + '/message', {'message': {'id': MESSAGE, 'text': 'Stream delivery fixture'}}, A)
        existing = sent.get('message', {})
    checks['member_can_send'] = existing.get('text') == 'Stream delivery fixture' and existing.get('type') == 'regular'
    status, channel = request(path + '/query', {'state': True, 'watch': False, 'messages': {'limit': 100}}, B)
    checks['recipient_can_read'] = 200 <= status < 300 and any(m['id'] == MESSAGE for m in channel.get('messages', []))
    status, _ = request(path + '/query', {'state': True, 'watch': False}, OUTSIDER)
    checks['nonmember_cannot_read'] = status == 403
    status, _ = request('channels/blab/unauthorized-fixture/query', {'data': {'members': [A, B]}, 'state': False, 'watch': False}, A)
    checks['user_cannot_create_channel'] = status == 403
    status, rejected = request(path + '/message', {'message': {'text': (' '.join('word' + str(i) for i in range(500)))[:2001]}}, A)
    # Stream can return HTTP 201 with type:error. It is not an accepted message.
    checks['message_limit_enforced'] = status == 400 or rejected.get('message', {}).get('type') == 'error'
    status, channel = request(path + '/query', {'state': True, 'watch': False, 'messages': {'limit': 100}}, B)
    checks['rejected_message_not_delivered'] = 200 <= status < 300 and not any(len(m.get('text', '')) > 2000 or m.get('type') == 'error' for m in channel.get('messages', []))
    result = {'isolated_app': '1731706', 'checks': checks, 'scope': 'Stream API fixture checks; not Supabase endpoint, Android, migration, or production verification'}
    OUTPUT.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'passed': sum(checks.values()), 'total': len(checks), 'checks': checks}))
    raise SystemExit(0 if all(checks.values()) else 1)

if __name__ == '__main__':
    main()
