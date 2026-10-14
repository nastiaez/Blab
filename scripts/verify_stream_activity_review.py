"""Owned synthetic endpoints + actual vendor metadata; never prints tokens."""
import json
import urllib.request
import urllib.error
from pathlib import Path

CHAT = '71000000-0000-4000-8000-000000000001'
MESSAGE = '71000000-0000-4000-8000-000000000017'

def main():
    config = json.loads(Path('/tmp/blab-stream-local-status.json').read_text())
    root = config['API_URL']
    if root != 'http://127.0.0.1:54441':
        raise SystemExit('Refusing non-owned backend')
    key = config.get('ANON_KEY') or config['PUBLISHABLE_KEY']
    admin = config.get('SERVICE_ROLE_KEY') or config['SECRET_KEY']
    def call(path, body=None, token=None, method=None):
        request = urllib.request.Request(root + path,
            data=None if body is None else json.dumps(body).encode(), method=method,
            headers={'apikey': key, 'Content-Type': 'application/json',
                     **({'Authorization': 'Bearer ' + token} if token else {})})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.status, json.load(response)
        except urllib.error.HTTPError as error:
            return error.code, json.load(error)
    def login(name):
        code, data = call('/auth/v1/token?grant_type=password', {'email': name + '@blab.test', 'password': 'Blab-local-123!'})
        if code != 200: raise SystemExit('Synthetic identity unavailable')
        return data['access_token'], data['user']['id']
    alice, alice_id = login('alice')
    bob, bob_id = login('bob')
    checks = {}
    command = {'chatId': CHAT, 'messageId': MESSAGE, 'requestId': MESSAGE, 'action': 'send', 'body': '👋'}
    code, ack = call('/functions/v1/stream-message', command, alice)
    checks['server_command_accepted'] = code == 200 and ack.get('id') == MESSAGE
    if not checks['server_command_accepted']:
        print(json.dumps({'status': code, 'error': ack.get('error')})); raise SystemExit(1)
    code, replay = call('/functions/v1/stream-message', command, alice)
    checks['command_retry_same_ack'] = code == 200 and replay == ack
    code, inbox = call('/rest/v1/stream_event_inbox?event_id=eq.command%3A' + MESSAGE + '&select=event_id,status', token=admin)
    checks['durable_recovery_before_ack'] = code == 200 and len(inbox) == 1
    code, auth = call('/functions/v1/stream-token', {}, bob)
    if code != 200: raise SystemExit('Vendor reader unavailable')
    def canonical():
        request = urllib.request.Request('https://chat.stream-io-api.com/messages/' + MESSAGE + '?api_key=' + auth['apiKey'], headers={'Authorization': auth['token'], 'Stream-Auth-Type': 'jwt'})
        with urllib.request.urlopen(request, timeout=15) as response: return json.load(response)['message']
    before = canonical()
    def activity(action, token=bob, **fields):
        return call('/functions/v1/stream-activity', {'chatId': CHAT, 'action': action, 'messageIds': [MESSAGE], **fields}, token)
    code, result = activity('read', userId=alice_id)
    checks['authenticated_recipient_read'] = code == 200
    after = canonical()
    checks['read_does_not_reauthor_or_edit_text'] = after.get('user', {}).get('id') == before.get('user', {}).get('id') == alice_id and after.get('text') == before.get('text') and after.get('message_text_updated_at') == before.get('message_text_updated_at')
    checks['read_identity_not_caller_field'] = after.get('blab_read_by') == [bob_id]
    code, _ = activity('react', emoji='❤️')
    checks['unicode_reaction_accepted'] = code == 200
    code, _ = activity('react', emoji='👍')
    reactions = canonical().get('latest_reactions', [])
    checks['one_reaction_per_person'] = code == 200 and len(reactions) == 1 and reactions[0].get('blab_emoji') == '👍'
    # Drain canonical recovery, not fabricated projection payloads.
    for _ in range(8):
        code, value = call('/functions/v1/reconcile-stream-events', {}, admin)
        if code != 200: break
        if value.get('processed') == 0: break
    code, reads = call('/rest/v1/message_reads?message_id=eq.' + MESSAGE + '&select=user_id', token=bob)
    checks['recipient_index_from_canonical'] = code == 200 and any(row['user_id'] == bob_id for row in reads)
    code, emojis = call('/rest/v1/message_reactions?message_id=eq.' + MESSAGE + '&select=emoji,user_id', token=bob)
    checks['emoji_index_from_canonical'] = code == 200 and len(emojis) == 1 and emojis[0]['emoji'] == '👍'
    code, _ = activity('unreact')
    checks['reaction_removal_canonical'] = code == 200 and canonical().get('latest_reactions', []) == []
    code, value = activity('typing.start')
    checks['typing_server_event_contract'] = code == 200
    activity('typing.stop')
    evidence = {'scope': 'Owned local authenticated endpoints + actual Stream; not Android/privacy-OFF acceptance', 'message_id': MESSAGE, 'checks': checks}
    Path('docs/qa/2026-10-14-stream-delivery/vendor-activity-checks.json').write_text(json.dumps(evidence, indent=2) + '\n')
    print(json.dumps({'passed': sum(checks.values()), 'total': len(checks), 'checks': checks}))
    if not all(checks.values()): raise SystemExit(1)

if __name__ == '__main__': main()
