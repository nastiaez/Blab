import copy
import unittest
from stream_history_readback import verify_history
from stream_history_snapshot import build_snapshot
from test_stream_history_snapshot import fixture, A, B, C, M


def readback(rows):
    messages = []
    for row in rows:
        if row['type'] == 'message':
            data = copy.deepcopy(row['data'])
            data['user'] = {'id': data['user']}
            data['cid'] = data['channel_type'] + ':' + data['channel_id']
            data['latest_reactions'] = [{'user_id': r['data']['user_id'],
                                        'blab_emoji': r['data']['blab_emoji']}
                                       for r in rows if r['type'] == 'reaction' and
                                       r['data']['message_id'] == data['id']]
            messages.append(data)
    members = [(r['data']['channel_id'], r['data']['user_id'])
               for r in rows if r['type'] == 'member']
    return messages, members


class ReadbackTests(unittest.TestCase):
    def test_complete_readback_produces_private_proof(self):
        rows = build_snapshot(fixture())
        report = verify_history(rows, *readback(rows))
        self.assertEqual(report['messages'], 1)
        self.assertEqual(report['reactions'], 1)
        self.assertNotIn('Original', str(report))

    def test_missing_extra_duplicate_and_wrong_member_rejected(self):
        rows = build_snapshot(fixture())
        messages, members = readback(rows)
        for bad, people in [([], members), (messages * 2, members),
                            (messages, members[:1]), (messages, members * 2)]:
            with self.assertRaises(ValueError):
                verify_history(rows, bad, people)

    def test_text_author_quote_reaction_and_hidden_receipt_drift_rejected(self):
        rows = build_snapshot(fixture())
        for drift in [{'text': 'Changed'}, {'user': {'id': B}},
                      {'quoted_message_id': M}, {'blab_read_by': [B]},
                      {'latest_reactions': []}, {'cid': 'blab:wrong'}]:
            messages, members = readback(rows)
            messages[0].update(drift)
            with self.assertRaises(ValueError):
                verify_history(rows, messages, members)

    def test_deleted_vendor_placeholder_is_accepted_but_restoration_is_not(self):
        source = fixture()
        source['messages'][0]['deleted_at'] = source['messages'][0]['created_at']
        rows = build_snapshot(source)
        messages, members = readback(rows)
        messages[0]['text'] = 'Vendor scrubbed placeholder'
        verify_history(rows, messages, members)
        messages[0].pop('deleted_at')
        with self.assertRaises(ValueError):
            verify_history(rows, messages, members)

    def test_private_media_reference_and_hashes_are_exact(self):
        source = fixture()
        source['messages'][0]['message_type'] = 'image'
        media = {'type': 'image', 'blab_asset_id': M, 'blab_source_hash': 'a' * 64,
                 'blab_preview_hash': 'b' * 64,
                 'blab_storage_bucket':'message-media', 'blab_storage_path':C+'/'+A+'/original.png', 'blab_preview_storage_path':C+'/'+A+'/preview.png'}
        rows = build_snapshot(source, {M: media})
        messages, members = readback(rows)
        verify_history(rows, messages, members)
        messages[0]['attachments'][0]['blab_source_hash'] = 'wrong'
        with self.assertRaises(ValueError):
            verify_history(rows, messages, members)


if __name__ == '__main__':
    unittest.main()
