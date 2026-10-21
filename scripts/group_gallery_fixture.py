#!/usr/bin/env python3
"""Seed real stored sample images into the isolated invite QA group, no hosted I/O."""
import json
import pathlib
import runpy
import urllib.request
import uuid

api = runpy.run_path('scripts/group_live_learning_qa.py')
call = api['call']
fixture = json.loads(pathlib.Path('build/group-entry-fixture.json').read_text())
group = str(uuid.UUID(fixture['group']))
session = call('/auth/v1/token?grant_type=password', {
    'email': 'eve.groupqa@blab.test', 'password': 'Blab-local-123!'})
token, uid = session['access_token'], session['user']['id']
data = pathlib.Path('assets/onboarding/mailbox-pixel-transparent.png').read_bytes()
for index in range(101):
    mid = str(uuid.uuid4())
    path = f'{group}/{uid}/{mid}.png'
    request = urllib.request.Request(
        api['BASE'] + '/storage/v1/object/message-media/' + path,
        data=data, method='POST', headers={
            'apikey': api['KEY'], 'Authorization': 'Bearer ' + token,
            'Content-Type': 'image/png'})
    with urllib.request.urlopen(request, timeout=30) as response:
        assert response.status == 200
    call('/rest/v1/messages', {'id': mid, 'chat_id': group,
         'sender_id': uid, 'body': '', 'message_type': 'image'}, token)
    call('/rest/v1/message_attachments', {'message_id': mid, 'chat_id': group,
         'storage_bucket': 'message-media', 'storage_path': path,
         'mime_type': 'image/png', 'byte_size': len(data)}, token)
print('Seeded101 real stored sample photos; no mocked picker/Storage results.')
