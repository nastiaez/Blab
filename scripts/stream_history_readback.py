"""Fail-closed, content-private comparison of a complete vendor history readback.

Callers must paginate the whole channel, fetch deleted IDs separately and freeze
the vendor channel before using a result as pre-traffic rollback evidence.
This module does not import data, activate chats or mutate either provider.
"""
import hashlib
import json
from datetime import datetime
from urllib.parse import urlsplit


def instant(value):
    result = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if result.tzinfo is None:
        raise ValueError('timezone_required')
    return result


def verify_history(rows, messages, members):
    expected = {r['data']['id']: r['data'] for r in rows if r['type'] == 'message'}
    actual = {m['id']: m for m in messages}
    if len(actual) != len(messages) or set(actual) != set(expected):
        raise ValueError('history_identity_mismatch')
    expected_members = {(r['data']['channel_id'], r['data']['user_id'])
                        for r in rows if r['type'] == 'member'}
    if set(members) != expected_members or len(members) != len(expected_members):
        raise ValueError('history_membership_mismatch')
    reactions = {}
    for row in rows:
        if row['type'] == 'reaction':
            r = row['data']
            reactions.setdefault(r['message_id'], []).append((r['user_id'], r['blab_emoji']))
    for mid, wanted in expected.items():
        found = actual[mid]
        if (found.get('cid') != wanted['channel_type'] + ':' + wanted['channel_id'] or
                found.get('user', {}).get('id') != wanted['user'] or
                instant(found['created_at']) != instant(wanted['created_at'])):
            raise ValueError('history_identity_mismatch')
        deleted = wanted['type'] == 'deleted'
        if bool(found.get('deleted_at')) != deleted:
            raise ValueError('history_deletion_mismatch')
        if deleted:
            if instant(found['deleted_at']) != instant(wanted['deleted_at']):
                raise ValueError('history_deletion_mismatch')
            # Stream scrubs deleted text to a vendor-owned placeholder.
        elif found.get('text') != wanted['text']:
            raise ValueError('history_text_mismatch')
        for key in ['quoted_message_id', 'blab_legacy_edited', 'blab_languages_matched_at_send']:
            if found.get(key) != wanted.get(key):
                raise ValueError('history_metadata_mismatch')
        if wanted.get('blab_legacy_edited_at') and (not found.get('blab_legacy_edited_at') or
                instant(found['blab_legacy_edited_at']) != instant(wanted['blab_legacy_edited_at'])):
            raise ValueError('history_edit_time_mismatch')
        if sorted(found.get('blab_read_by') or []) != sorted(wanted['blab_read_by']):
            raise ValueError('history_receipt_mismatch')
        got_reactions = [(r.get('user_id') or r.get('user', {}).get('id'),
                          r.get('blab_emoji') or r.get('emoji_code'))
                         for r in found.get('latest_reactions') or []]
        if sorted(got_reactions) != sorted(reactions.get(mid, [])):
            raise ValueError('history_reaction_mismatch')
        wanted_assets, got_assets = wanted['attachments'], found.get('attachments') or []
        if len(wanted_assets) != len(got_assets):
            raise ValueError('history_media_mismatch')
        for left, right in zip(wanted_assets, got_assets):
            for key in ['type', 'blab_asset_id', 'blab_source_hash', 'blab_preview_hash']:
                if left.get(key) != right.get(key):
                    raise ValueError('history_media_mismatch')
            if left.get('blab_storage_bucket'):
                for key in ['blab_storage_bucket','blab_storage_path','blab_preview_storage_path']:
                    if left.get(key) != right.get(key):
                        raise ValueError('history_media_mismatch')
                if any(key in right for key in ['asset_url','thumb_url','image_url']):
                    raise ValueError('history_media_mismatch')
            else:  # Read-only comparison of earlier owned CDN fixtures.
                for key in ['asset_url', 'thumb_url']:
                    a, b = urlsplit(left[key]), urlsplit(right[key])
                    if (a.scheme, a.netloc, a.path) != (b.scheme, b.netloc, b.path):
                        raise ValueError('history_media_mismatch')
    # Hash only the complete approved expected snapshot; no plaintext in report.
    digest = hashlib.sha256(json.dumps(rows, ensure_ascii=False, sort_keys=True,
                                      separators=(',', ':')).encode()).hexdigest()
    return {'messages': len(expected), 'members': len(expected_members),
            'reactions': sum(map(len, reactions.values())), 'proofHash': digest}
