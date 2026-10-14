import 'package:flutter_test/flutter_test.dart';
import 'package:stream_chat/stream_chat.dart' as stream;

import 'package:blab/shared/data/stream_message_mapper.dart';
import 'package:blab/shared/models/message.dart';

void main() {
  final at = DateTime.utc(2026, 10, 14, 9);
  stream.Message message({
    String type = 'regular',
    String? text = 'Original',
  }) => stream.Message(
    id: 'message',
    user: stream.User(id: 'alice'),
    text: text,
    createdAt: at,
    type: type,
  );
  Message? map(stream.Message source) =>
      messageFromStream(source, chatId: 'chat', currentUserId: 'alice');
  test(
    'exact authored text, stable identity and historical match survive mapping',
    () {
      final result = map(
        message(
          text: 'Hello\n  world',
        ).copyWith(extraData: {'blab_languages_matched_at_send': true}),
      )!;
      expect(result.originalText, 'Hello\n  world');
      expect(result.id, 'message');
      expect(result.sentAt.toUtc(), at);
      expect(result.isOutgoing, true);
      expect(result.languagesMatchedAtSend, true);
      expect(result.translation, '');
    },
  );
  test(
    'error acknowledgments and deleted messages cannot become delivered bubbles',
    () {
      for (final type in ['error', 'ephemeral', 'system', 'deleted']) {
        expect(map(message(type: type)), isNull);
      }
      expect(map(message().copyWith(deletedAt: at)), isNull);
    },
  );
  test('imported historical edit markers survive without a new edit event', () {
    expect(
      map(
        message().copyWith(extraData: {'blab_legacy_edited': true}),
      )!.isEdited,
      isTrue,
    );
  });
  test(
    'missing authoritative sender or timestamp is not displayed as a new message',
    () {
      expect(
        map(
          stream.Message(
            text: 'No timestamp',
            user: stream.User(id: 'alice'),
          ),
        ),
        isNull,
      );
      expect(map(stream.Message(text: 'No sender', createdAt: at)), isNull);
    },
  );
  test(
    'deleted quotation is a one-level tombstone without exposing old text',
    () {
      final quote = message(text: 'Must stay hidden').copyWith(
        deletedAt: at,
        quotedMessage: message(text: 'Nested private text'),
      );
      final result = map(message().copyWith(quotedMessage: quote))!;
      expect(result.replyTo!.originalText, 'Deleted message');
      expect(result.replyTo!.replyTo, isNull);
      expect(result.replyTo!.attachment, isNull);
    },
  );
  test(
    'image and caption preserve existing full-image and preview rendering',
    () {
      final result = map(
        message(text: 'Caption').copyWith(
          attachments: [
            stream.Attachment(
              id: 'photo',
              type: 'image',
              imageUrl: 'https://example.test/full.jpg',
              assetUrl: 'https://example.test/untouched.jpg',
              thumbUrl: 'https://example.test/thumb.jpg',
              extraData: {
                'file_size': 123,
                'mime_type': 'image/jpeg',
                'blab_asset_id': 'stable-asset',
                'blab_preview_mime_type': 'image/jpeg',
                'blab_preview_file_size': 24,
              },
            ),
          ],
        ),
      )!;
      expect(result.type, MessageType.image);
      expect(result.originalText, 'Caption');
      expect(result.attachment!.url, 'https://example.test/untouched.jpg');
      expect(result.attachment!.id, 'stable-asset');
      expect(result.attachment!.previewByteSize, 24);
      expect(result.attachment!.previewUrl, 'https://example.test/thumb.jpg');
      expect(result.attachment!.byteSize, 123);
    },
  );
  test('reaction-only updates do not invent an edited label', () {
    expect(
      map(
        message().copyWith(updatedAt: at.add(const Duration(minutes: 1))),
      )!.isEdited,
      false,
    );
    expect(
      map(
        message().copyWith(
          messageTextUpdatedAt: at.add(const Duration(minutes: 1)),
        ),
      )!.isEdited,
      true,
    );
  });
  test('private photo references require no public vendor URL', () {
    final result = map(
      message().copyWith(
        attachments: [
          stream.Attachment(
            type: 'image',
            extraData: {
              'blab_asset_id': 'private-photo',
              'blab_storage_bucket': 'stream-private-media',
              'blab_storage_path': 'chat/alice/photo/lease/original.png',
              'blab_preview_storage_path': 'chat/alice/photo/lease/preview.jpg',
            },
          ),
        ],
      ),
    )!;
    expect(result.attachment!.storageBucket, 'stream-private-media');
    expect(
      result.attachment!.previewStoragePath,
      'chat/alice/photo/lease/preview.jpg',
    );
    expect(result.attachment!.url, isNull);
  });
}
