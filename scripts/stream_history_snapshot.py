"""Pure complete history export. Never activates chats or calls a provider.

Input is an authorized, consistent database snapshot. Private learning/profile
fields are deliberately not serialized. Media must already have verified CDN
metadata; expiring Supabase URLs cannot enter a historical import.
"""
import hashlib
from datetime import datetime
from uuid import UUID


def identity(value):
    if str(UUID(value)) != value:
        raise ValueError('invalid_identity')
    return value


def timestamp(value):
    parsed = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if parsed.tzinfo is None:
        raise ValueError('timezone_required')
    return value


def indexed(rows):
    result = {}
    for row in rows:
        key = identity(row['id'])
        if key in result:
            raise ValueError('duplicate_identity')
        result[key] = row
    return result


def partition_ready_chats(source):
    """An unclaimed one-person invite stays Supabase-owned, never half-imported."""
    sizes = {}
    for member in source['members']:
        sizes.setdefault(member['chat_id'], set()).add(member['user_id'])
    ready = {chat['id'] for chat in source['chats'] if len(sizes.get(chat['id'], set())) == 2}
    held = [chat['id'] for chat in source['chats'] if chat['id'] not in ready]
    members = [m for m in source['members'] if m['chat_id'] in ready]
    users = {m['user_id'] for m in members}
    messages = [m for m in source['messages'] if m['chat_id'] in ready]
    ids = {m['id'] for m in messages}
    return {
        'profiles': [p for p in source['profiles'] if p['id'] in users],
        'chats': [c for c in source['chats'] if c['id'] in ready],
        'members': members, 'messages': messages,
        'reads': [r for r in source.get('reads', []) if r['message_id'] in ids],
        'reactions': [r for r in source.get('reactions', []) if r['message_id'] in ids],
        'attachments': [a for a in source.get('attachments', []) if a['message_id'] in ids],
    }, held


def build_snapshot(source, verified_media=None):
    users = indexed(source['profiles'])
    chats = indexed(source['chats'])
    messages = indexed(source['messages'])
    verified_media = verified_media or {}
    membership = {}
    for member in source['members']:
        pair = (member['chat_id'], member['user_id'])
        if pair in membership or pair[0] not in chats or pair[1] not in users:
            raise ValueError('invalid_membership')
        membership[pair] = member
    for chat in chats:
        if sum(pair[0] == chat for pair in membership) != 2:
            raise ValueError('expected_two_participants')
    reads = {}
    for read in source.get('reads', []):
        message = messages.get(read['message_id'])
        if message is None or (message['chat_id'], read['user_id']) not in membership:
            raise ValueError('invalid_reader')
        if read.get('receipt_visible', True):
            reads.setdefault(message['id'], {})[read['user_id']] = timestamp(read['read_at'])
    output = []
    for uid, user in sorted(users.items()):
        data = {'id': uid, 'name': user['display_name'], 'role': 'user',
                'created_at': timestamp(user['created_at']),
                'privacy_settings': {name: {'enabled': False} for name in
                    ['read_receipts', 'delivery_receipts', 'typing_indicators']}}
        if user.get('avatar_url'):
            data['image'] = user['avatar_url']
        output.append({'type': 'user', 'data': data})
    for cid, chat in sorted(chats.items()):
        participants = sorted(uid for (chat_id, uid) in membership if chat_id == cid)
        output.append({'type': 'channel', 'data': {
            'id': cid, 'type': 'blab', 'created_by': participants[0],
            'created_at': timestamp(chat['created_at']), 'frozen': False,
            'disabled': False}})
    for (cid, uid), member in sorted(membership.items()):
        # Vendor prefix receipts are not Blab's per-visible-message receipts.
        output.append({'type': 'member', 'data': {
            'channel_id': cid, 'channel_type': 'blab', 'user_id': uid,
            'channel_role': 'channel_member',
            'created_at': timestamp(member['joined_at'])}})
    ordered = sorted(messages.values(), key=lambda m: (
        datetime.fromisoformat(timestamp(m['created_at']).replace('Z', '+00:00')), m['id']))
    for message in ordered:
        mid, cid, uid = message['id'], message['chat_id'], message['sender_id']
        if (cid, uid) not in membership:
            raise ValueError('invalid_author')
        quote = message.get('reply_to')
        if quote and (quote not in messages or messages[quote]['chat_id'] != cid):
            raise ValueError('invalid_quote')
        deleted = message.get('deleted_at')
        data = {'id': mid, 'channel_id': cid, 'channel_type': 'blab', 'user': uid,
                'type': 'deleted' if deleted else 'regular',
                'text': '' if deleted else message['body'],
                'created_at': timestamp(message['created_at']),
                'attachments': [],
                'blab_languages_matched_at_send': message.get('languages_matched_at_send') is True,
                'blab_read_by': sorted(reads.get(mid, {})),
                'blab_legacy_edited': bool(message.get('edited_at'))}
        if quote:
            data['quoted_message_id'] = quote
        if message.get('edited_at'):
            data['blab_legacy_edited_at'] = timestamp(message['edited_at'])
        if deleted:
            data['deleted_at'] = timestamp(deleted)
        elif message.get('message_type') == 'image':
            attachment = verified_media.get(mid)
            if not attachment or attachment.get('blab_asset_id') != mid:
                raise ValueError('unverified_media')
            if attachment.get('blab_storage_bucket') not in ['message-media', 'stream-private-media']:
                raise ValueError('private_media_required')
            for key in ['blab_storage_path', 'blab_preview_storage_path']:
                path = attachment.get(key, '')
                if not path.startswith(cid + '/' + uid + '/') or '..' in path:
                    raise ValueError('invalid_private_media')
            if any(key in attachment for key in ['asset_url','thumb_url','image_url']):
                raise ValueError('public_media_url_forbidden')
            allowed = ['id','type','mime_type','file_size','blab_asset_id','blab_source_hash',
                       'blab_preview_hash','blab_storage_bucket','blab_storage_path',
                       'blab_preview_storage_path','blab_preview_mime_type','blab_preview_file_size']
            data['attachments'] = [{key:attachment[key] for key in allowed if key in attachment}]
        output.append({'type': 'message', 'data': data})
    reactions_seen = set()
    for reaction in sorted(source.get('reactions', []), key=lambda r: (r['message_id'], r['user_id'])):
        mid, uid = reaction['message_id'], reaction['user_id']
        message = messages.get(mid)
        if message is None or (message['chat_id'], uid) not in membership or (mid, uid) in reactions_seen:
            raise ValueError('invalid_reaction')
        reactions_seen.add((mid, uid))
        if message.get('deleted_at'):
            continue
        emoji = reaction['emoji']
        if not emoji or len(emoji) > 32 or emoji != emoji.strip():
            raise ValueError('invalid_emoji')
        output.append({'type': 'reaction', 'data': {
            'message_id': mid, 'user_id': uid,
            'type': 'blab_' + hashlib.sha256(emoji.encode()).hexdigest()[:24],
            'blab_emoji': emoji, 'emoji_code': emoji, 'score': 1,
            'created_at': timestamp(reaction['created_at'])}})
    return output
