import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blab/shared/data/local_storage_keys.dart';
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
    final firstUsedAt =
        (jsonDecode(firstIndex!) as List).single['usedAt'] as num;

    await Future<void>.delayed(const Duration(milliseconds: 1));
    await cache.loadAttachmentBytes('attachment-1');
    final secondIndex = prefs.getString('cached_attachment_index:alice');
    expect(secondIndex, contains('attachment-1'));
    final secondUsedAt =
        (jsonDecode(secondIndex!) as List).single['usedAt'] as num;
    expect(secondUsedAt, greaterThan(firstUsedAt));
  });

  test('ordinary touch does not decode indexed sibling bytes', () async {
    final cache = LocalChatHistoryCache('alice');
    await cache.saveAttachmentBytes('sibling', [1, 2, 3]);
    await cache.saveAttachmentBytes('current', [4, 5, 6]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      cachedAttachmentStorageKey(userId: 'alice', attachmentId: 'sibling'),
      'corrupt-sibling-bytes!',
    );

    await cache.loadAttachmentBytes('current');

    final indexRows =
        (jsonDecode(prefs.getString(cachedAttachmentIndexStorageKey('alice'))!)
                as List)
            .cast<Map>();
    expect(indexRows.map((row) => row['id']), contains('sibling'));
    expect(indexRows.singleWhere((row) => row['id'] == 'sibling')['size'], 3);
  });

  test('concurrent full-photo saves stay within the account budget', () async {
    final firstCache = LocalChatHistoryCache('alice');
    final secondCache = LocalChatHistoryCache('alice');
    await firstCache.saveAttachmentBytes('old', Uint8List(10 * 1024 * 1024));

    await Future.wait([
      firstCache.saveAttachmentBytes('first', Uint8List(11 * 1024 * 1024)),
      secondCache.saveAttachmentBytes('second', Uint8List(11 * 1024 * 1024)),
    ]);

    final prefs = await SharedPreferences.getInstance();
    final storedIds = ['first', 'second'].where((id) {
      return prefs.getString(
            cachedAttachmentStorageKey(userId: 'alice', attachmentId: id),
          ) !=
          null;
    }).toList();
    final indexRows =
        (jsonDecode(prefs.getString(cachedAttachmentIndexStorageKey('alice'))!)
                as List)
            .cast<Map>();

    expect(storedIds, hasLength(1));
    expect(indexRows.map((row) => row['id']), storedIds);
    expect(
      prefs.getString(
        cachedAttachmentStorageKey(userId: 'alice', attachmentId: 'old'),
      ),
      isNull,
    );
  });

  test('wrong-type full-photo index does not suppress valid bytes', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      cachedAttachmentStorageKey(userId: 'alice', attachmentId: 'full'),
      base64Encode([1, 2, 3]),
    );
    await prefs.setInt(cachedAttachmentIndexStorageKey('alice'), 123);
    final cache = LocalChatHistoryCache('alice');

    expect(await cache.loadAttachmentBytes('full'), [1, 2, 3]);
    expect(prefs.get(cachedAttachmentIndexStorageKey('alice')), isA<String>());
  });

  test('malformed index rows reconcile orphaned full-photo bytes', () async {
    final prefs = await SharedPreferences.getInstance();
    final fullBytes = Uint8List(11 * 1024 * 1024);
    await prefs.setString(
      cachedAttachmentStorageKey(userId: 'alice', attachmentId: 'orphan'),
      base64Encode(fullBytes),
    );
    await prefs.setString(
      cachedAttachmentStorageKey(userId: 'alice', attachmentId: 'active'),
      base64Encode(fullBytes),
    );
    await prefs.setString(
      cachedAttachmentPreviewStorageKey(
        userId: 'alice',
        attachmentId: 'legacy',
      ),
      base64Encode([4]),
    );
    await prefs.setString(
      cachedAttachmentIndexStorageKey('alice'),
      jsonEncode([
        {'id': 'active', 'size': fullBytes.length, 'usedAt': 'bad'},
        {'id': 'orphan', 'size': -1, 'usedAt': 0},
        {'id': 'preview:legacy', 'size': 1, 'usedAt': 0},
      ]),
    );
    final cache = LocalChatHistoryCache('alice');

    final loaded = await cache.loadAttachmentBytes('active');

    expect(loaded, hasLength(fullBytes.length));
    expect(
      prefs.containsKey(
        cachedAttachmentStorageKey(userId: 'alice', attachmentId: 'orphan'),
      ),
      isFalse,
    );
    expect(await cache.loadAttachmentPreviewBytes('legacy'), [4]);
    final normalizedRows =
        (jsonDecode(prefs.getString(cachedAttachmentIndexStorageKey('alice'))!)
                as List)
            .cast<Map>();
    expect(normalizedRows, hasLength(1));
    expect(normalizedRows.single['id'], 'active');
    expect(normalizedRows.single['size'], fullBytes.length);
    expect((normalizedRows.single['usedAt'] as num).isFinite, isTrue);
  });

  test('repair removes wrong-type orphan full-photo values', () async {
    final cache = LocalChatHistoryCache('alice');
    await cache.saveAttachmentBytes('indexed', [1]);
    final prefs = await SharedPreferences.getInstance();
    final orphanKey = cachedAttachmentStorageKey(
      userId: 'alice',
      attachmentId: 'orphan',
    );
    await prefs.setInt(orphanKey, 123);

    await cache.loadAttachmentBytes('indexed');

    expect(prefs.containsKey(orphanKey), isFalse);
  });

  test('cached preview survives full-photo LRU pressure', () async {
    final cache = LocalChatHistoryCache('alice');
    await cache.saveAttachmentPreviewBytes('preview', [4, 5, 6]);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(cachedAttachmentIndexStorageKey('alice')),
      isNot(contains('preview:')),
    );

    await cache.saveAttachmentBytes(
      'full',
      List<int>.filled(20 * 1024 * 1024, 7),
    );

    expect(await cache.loadAttachmentPreviewBytes('preview'), [4, 5, 6]);
    expect(
      prefs.getString(cachedAttachmentIndexStorageKey('alice')),
      isNot(contains('preview:')),
    );
  });

  test('wrong-type preview bytes load as absent media', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      cachedAttachmentPreviewStorageKey(
        userId: 'alice',
        attachmentId: 'preview',
      ),
      123,
    );

    await expectLater(
      LocalChatHistoryCache('alice').loadAttachmentPreviewBytes('preview'),
      completion(isNull),
    );
  });

  test(
    'legacy preview index row is removed without deleting preview bytes',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        cachedAttachmentPreviewStorageKey(
          userId: 'alice',
          attachmentId: 'legacy',
        ),
        base64Encode([4]),
      );
      await prefs.setString(
        cachedAttachmentIndexStorageKey('alice'),
        jsonEncode([
          {'id': 'preview:legacy', 'size': 1, 'usedAt': 0},
        ]),
      );
      final cache = LocalChatHistoryCache('alice');

      await cache.saveAttachmentBytes(
        'full',
        List<int>.filled(20 * 1024 * 1024, 7),
      );

      expect(await cache.loadAttachmentPreviewBytes('legacy'), [4]);
      expect(
        prefs.getString(cachedAttachmentIndexStorageKey('alice')),
        isNot(contains('preview:')),
      );
    },
  );

  test('corrupt full photo bytes preserve messages and preview', () async {
    final cache = await _seedPhotoConversation();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      cachedAttachmentStorageKey(userId: 'alice', attachmentId: 'attachment-1'),
      'corrupt-full-bytes!',
    );

    final restored = await cache.loadMessages('chat-1');

    expect(restored.map((message) => message.id), [
      'image-message',
      'text-message',
    ]);
    final attachment = restored.first.attachment;
    expect(attachment?.id, 'attachment-1');
    expect(attachment?.messageId, 'image-message');
    expect(attachment?.storageBucket, 'message-media');
    expect(attachment?.storagePath, 'chat-1/attachment-1.jpg');
    expect(attachment?.previewStoragePath, 'chat-1/attachment-1.preview.jpg');
    expect(attachment?.localBytes, isNull);
    expect(attachment?.previewBytes, [4, 5, 6]);
  });

  test(
    'corrupt preview photo bytes preserve messages and full image',
    () async {
      final cache = await _seedPhotoConversation();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        cachedAttachmentPreviewStorageKey(
          userId: 'alice',
          attachmentId: 'attachment-1',
        ),
        'corrupt-preview-bytes!',
      );

      final restored = await cache.loadMessages('chat-1');

      expect(restored.map((message) => message.id), [
        'image-message',
        'text-message',
      ]);
      final attachment = restored.first.attachment;
      expect(attachment?.id, 'attachment-1');
      expect(attachment?.localBytes, [1, 2, 3]);
      expect(attachment?.previewBytes, isNull);
    },
  );

  test('wrong-type full photo cache does not hide offline messages', () async {
    final cache = await _seedPhotoConversation();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      cachedAttachmentStorageKey(userId: 'alice', attachmentId: 'attachment-1'),
      123,
    );

    final restored = await cache.loadMessages('chat-1');

    expect(restored.map((message) => message.id), [
      'image-message',
      'text-message',
    ]);
    expect(restored.first.attachment?.localBytes, isNull);
    expect(restored.first.attachment?.previewBytes, [4, 5, 6]);
  });

  test(
    'wrong-type preview photo cache does not hide offline messages',
    () async {
      final cache = await _seedPhotoConversation();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        cachedAttachmentPreviewStorageKey(
          userId: 'alice',
          attachmentId: 'attachment-1',
        ),
        123,
      );

      final restored = await cache.loadMessages('chat-1');

      expect(restored.map((message) => message.id), [
        'image-message',
        'text-message',
      ]);
      expect(restored.first.attachment?.localBytes, [1, 2, 3]);
      expect(restored.first.attachment?.previewBytes, isNull);
    },
  );

  test('empty cached photo byte strings restore as absent media', () async {
    final cache = await _seedPhotoConversation();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      cachedAttachmentStorageKey(userId: 'alice', attachmentId: 'attachment-1'),
      '',
    );
    await prefs.setString(
      cachedAttachmentPreviewStorageKey(
        userId: 'alice',
        attachmentId: 'attachment-1',
      ),
      '',
    );

    final restored = await cache.loadMessages('chat-1');

    expect(restored.map((message) => message.id), [
      'image-message',
      'text-message',
    ]);
    expect(restored.first.attachment?.localBytes, isNull);
    expect(restored.first.attachment?.previewBytes, isNull);
  });

  test(
    'a single oversized attachment is evicted instead of exceeding budget',
    () async {
      final cache = LocalChatHistoryCache('alice');
      await cache.saveAttachmentBytes(
        'oversized',
        List<int>.filled(20 * 1024 * 1024 + 1, 7),
      );

      expect(await cache.loadAttachmentBytes('oversized'), isNull);
    },
  );
}

Future<LocalChatHistoryCache> _seedPhotoConversation() async {
  final cache = LocalChatHistoryCache('alice');
  await cache.saveMessages('chat-1', [
    Message(
      id: 'image-message',
      chatId: 'chat-1',
      isOutgoing: false,
      originalText: '',
      translation: '',
      sentAt: DateTime.utc(2026, 8, 28, 10),
      status: MessageStatus.delivered,
      type: MessageType.image,
      attachment: const MessageAttachment(
        id: 'attachment-1',
        messageId: 'image-message',
        chatId: 'chat-1',
        storageBucket: 'message-media',
        storagePath: 'chat-1/attachment-1.jpg',
        mimeType: 'image/jpeg',
        byteSize: 3,
        previewStoragePath: 'chat-1/attachment-1.preview.jpg',
        previewMimeType: 'image/jpeg',
        previewByteSize: 3,
        localBytes: [1, 2, 3],
        previewBytes: [4, 5, 6],
      ),
    ),
    Message(
      id: 'text-message',
      chatId: 'chat-1',
      isOutgoing: true,
      originalText: 'Still here',
      translation: '',
      sentAt: DateTime.utc(2026, 8, 28, 11),
      status: MessageStatus.delivered,
    ),
  ]);
  return cache;
}
