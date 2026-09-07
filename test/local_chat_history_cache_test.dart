import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/services/local_chat_history_cache.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('restores account-scoped messages and attachment bytes', () async {
    final cache = LocalChatHistoryCache('alice');
    final sentAt = DateTime.utc(2026, 8, 28, 10);
    await cache.saveMessages('chat-1', [
      Message(
        id: 'message-1',
        chatId: 'chat-1',
        isOutgoing: false,
        originalText: 'Привіт',
        translation: '',
        sentAt: sentAt,
        status: MessageStatus.delivered,
        attachment: const MessageAttachment(
          id: 'attachment-1',
          messageId: 'message-1',
          chatId: 'chat-1',
          storageBucket: 'message-media',
          storagePath: 'chat-1/attachment-1.jpg',
          mimeType: 'image/jpeg',
          byteSize: 3,
          previewStoragePath: 'chat-1/attachment-1.preview.jpg',
          previewMimeType: 'image/jpeg',
          previewByteSize: 3,
          localBytes: [1, 2, 3],
        ),
      ),
    ]);

    final restored = await cache.loadMessages('chat-1');
    expect(restored, hasLength(1));
    expect(restored.single.originalText, 'Привіт');
    expect(
      restored.single.attachment?.previewStoragePath,
      'chat-1/attachment-1.preview.jpg',
    );
    expect(restored.single.attachment?.localBytes, [1, 2, 3]);
    expect(await LocalChatHistoryCache('bob').loadMessages('chat-1'), isEmpty);
  });

  test('touching a cached attachment updates its LRU index', () async {
    final cache = LocalChatHistoryCache('alice');
    await cache.saveAttachmentBytes('attachment-1', [1]);
    final prefs = await SharedPreferences.getInstance();
    final firstIndex = prefs.getString('cached_attachment_index:alice');
    expect(firstIndex, contains('attachment-1'));

    await cache.loadAttachmentBytes('attachment-1');
    final secondIndex = prefs.getString('cached_attachment_index:alice');
    expect(secondIndex, contains('attachment-1'));
  });

  test(
    'a single oversized attachment is evicted instead of exceeding budget',
    () async {
      final cache = LocalChatHistoryCache('alice');
      await cache.saveAttachmentPreviewBytes(
        'oversized',
        List<int>.filled(20 * 1024 * 1024 + 1, 7),
      );

      expect(await cache.loadAttachmentPreviewBytes('oversized'), isNull);
    },
  );
}
