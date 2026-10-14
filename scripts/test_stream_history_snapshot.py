import copy
import unittest
from stream_history_snapshot import build_snapshot, partition_ready_chats

A = '90000000-0000-4000-8000-00000000000a'
B = '90000000-0000-4000-8000-00000000000b'
C = '90000000-0000-4000-8000-000000000001'
M = '90000000-0000-4000-8000-000000000002'
N = '90000000-0000-4000-8000-000000000003'
T = '2026-01-01T00:00:00Z'


def fixture():
    return {'profiles': [{'id': u, 'display_name': u[-1], 'created_at': T,
                          'known_languages': ['private'], 'email': 'private'} for u in [A, B]],
            'chats': [{'id': C, 'created_at': T}],
            'members': [{'chat_id': C, 'user_id': u, 'joined_at': T,
                         'learning_language': 'private'} for u in [A, B]],
            'messages': [{'id': M, 'chat_id': C, 'sender_id': A,
                          'body': 'Original', 'created_at': T,
                          'private_translation': 'Must not leave'}],
            'reads': [{'message_id': M, 'user_id': B, 'read_at': T,
                       'receipt_visible': False}],
            'reactions': [{'message_id': M, 'user_id': B, 'emoji': '❤️', 'created_at': T}]}


class HistorySnapshotTests(unittest.TestCase):
    def test_unclaimed_invite_is_held_without_copying_partial_membership(self):
        source = fixture()
        source['chats'].append({'id': N, 'created_at': T})
        source['members'].append({'chat_id': N, 'user_id': A, 'joined_at': T})
        ready, held = partition_ready_chats(source)
        self.assertEqual(held, [N])
        self.assertEqual(len(ready['chats']), 1)
        self.assertFalse(any(m['chat_id'] == N for m in ready['members']))
        self.assertTrue(build_snapshot(ready))

    def test_private_preferences_and_hidden_receipts_do_not_leave(self):
        rows = build_snapshot(fixture())
        self.assertNotIn('private', str(rows).lower())
        self.assertEqual(next(r['data'] for r in rows if r['type'] == 'message')['blab_read_by'], [])

    def test_exact_identity_text_and_visible_receipts(self):
        source = fixture()
        source['reads'][0]['receipt_visible'] = True
        rows = build_snapshot(source)
        message = next(r['data'] for r in rows if r['type'] == 'message')
        self.assertEqual((message['id'], message['text'], message['created_at']), (M, 'Original', T))
        self.assertEqual(message['blab_read_by'], [B])
        reaction = rows[-1]['data']
        self.assertEqual(reaction['blab_emoji'], '❤️')
        self.assertRegex(reaction['type'], r'^blab_[0-9a-f]{24}$')

    def test_deleted_quoted_messages_remain_scrubbed_tombstones(self):
        source = fixture()
        source['messages'][0]['deleted_at'] = T
        source['messages'].append({'id': N, 'chat_id': C, 'sender_id': B,
                                   'body': 'Reply', 'created_at': T, 'reply_to': M})
        rows = build_snapshot(source)
        messages = [r['data'] for r in rows if r['type'] == 'message']
        self.assertEqual(messages[0]['type'], 'deleted')
        self.assertEqual(messages[0]['text'], '')
        self.assertEqual(messages[1]['quoted_message_id'], M)
        self.assertFalse(any(r['type'] == 'reaction' for r in rows))

    def test_no_media_import_until_verified(self):
        source = fixture()
        source['messages'][0]['message_type'] = 'image'
        with self.assertRaisesRegex(ValueError, 'unverified_media'):
            build_snapshot(source)
        media = {'type': 'image', 'blab_asset_id': M,
                 'blab_storage_bucket':'message-media', 'blab_storage_path': C+'/'+A+'/original.png', 'blab_preview_storage_path': C+'/'+A+'/preview.png'}
        rows = build_snapshot(source, {M: media})
        self.assertEqual(next(r['data'] for r in rows if r['type'] == 'message')['attachments'], [media])
        with self.assertRaisesRegex(ValueError, 'public_media_url_forbidden'):
            build_snapshot(source, {M: {**media, 'asset_url': 'https://example/photo?token=expiring'}})

    def test_invalid_author_quote_duplicate_and_membership_rejected(self):
        for mutate in [
            lambda s: s['messages'][0].update(sender_id=N),
            lambda s: s['messages'][0].update(reply_to=N),
            lambda s: s['messages'].append(copy.deepcopy(s['messages'][0])),
            lambda s: s['members'].pop(),
        ]:
            source = fixture()
            mutate(source)
            with self.assertRaises(ValueError):
                build_snapshot(source)

    def test_offsets_sorted_by_actual_instant_not_lexical_string(self):
        source = fixture()
        source['messages'][0]['created_at'] = '2026-01-01T01:00:00+02:00'
        source['messages'].append({'id': N, 'chat_id': C, 'sender_id': B,
                                   'body': 'Later', 'created_at': T})
        ids = [r['data']['id'] for r in build_snapshot(source) if r['type'] == 'message']
        self.assertEqual(ids, [M, N])


if __name__ == '__main__':
    unittest.main()
