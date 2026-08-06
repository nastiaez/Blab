import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/features/chat/state/pending_sends_state.dart';
import 'package:blab/shared/data/local_storage_keys.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';

/// Fake send path. `throwOnSend` simulates a server rejection; every send
/// is counted so tests can assert whether the network was actually hit.
class _FakeChatService implements ChatService {
  int sendCalls = 0;
  int photoSendCalls = 0;
  bool throwOnSend = false;
  bool loseFirstResponse = false;
  final List<String> attemptedIds = <String>[];
  final List<String?> attemptedReplyIds = <String?>[];
  final List<String> attemptedPhotoCaptions = <String>[];
  final Set<String> committedIds = <String>{};

  @override
  Future<({String id, DateTime createdAt})> sendMessage({
    required String chatId,
    required String body,
    String? clientMessageId,
    String? replyToId,
  }) async {
    sendCalls++;
    if (throwOnSend) throw Exception('server_500');
    final id = clientMessageId ?? 'server-$sendCalls';
    attemptedIds.add(id);
    attemptedReplyIds.add(replyToId);
    if (loseFirstResponse && committedIds.add(id)) {
      throw TimeoutException('response_lost');
    }
    committedIds.add(id);
    return (id: id, createdAt: DateTime.parse('2026-06-09T00:00:00Z'));
  }

  @override
  Future<({String id, DateTime createdAt, MessageAttachment attachment})>
  sendPhotoMessage({
    required String chatId,
    required PickedChatImage image,
    required String caption,
    String? clientMessageId,
    String? replyToId,
  }) async {
    photoSendCalls++;
    if (throwOnSend) throw Exception('server_500');
    final id = clientMessageId ?? 'photo-server-$photoSendCalls';
    attemptedIds.add(id);
    attemptedReplyIds.add(replyToId);
    attemptedPhotoCaptions.add(caption);
    return (
      id: id,
      createdAt: DateTime.parse('2026-06-09T00:00:00Z'),
      attachment: MessageAttachment(
        id: 'att-$id',
        messageId: id,
        chatId: chatId,
        storageBucket: 'message-media',
        storagePath: '$chatId/user-a/$id.jpg',
        mimeType: image.mimeType,
        byteSize: image.bytes.length,
        url: 'https://example.test/$id.jpg',
      ),
    );
  }

  @override
  Future<List<Message>> fetchMessages(String chatId, {int limit = 50}) async =>
      const [];

  @override
  Future<MessagePage> fetchMessagePage(
    String chatId, {
    int limit = 50,
    MessageCursor? before,
  }) async => const MessagePage(messages: [], hasMore: false);

  @override
  Stream<MessageChange> watchMessageChanges(String chatId) =>
      const Stream.empty();

  @override
  Future<void> softDelete(String messageId) async {}

  @override
  Future<void> restoreMessage(String messageId) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchChatList() async => const [];

  @override
  Stream<List<Map<String, dynamic>>> watchMyMemberships() =>
      const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _id(int value) =>
    '00000000-0000-4000-8000-${value.toString().padLeft(12, '0')}';

ProviderContainer _container(
  _FakeChatService fake, {
  required bool online,
  bool? backendReachable,
  String userId = 'user-a',
}) {
  var nextId = 0;
  final c = ProviderContainer(
    overrides: [
      chatServiceProvider.overrideWithValue(fake),
      authSessionProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue(userId),
      isOnlineProvider.overrideWithValue(online),
      backendReachabilityCheckProvider.overrideWithValue(
        () async => backendReachable ?? online,
      ),
      clientMessageIdFactoryProvider.overrideWithValue(() => _id(++nextId)),
    ],
  );
  return c;
}

List<Message> _queue(ProviderContainer c, String chatId) =>
    c.read(pendingSendsProvider(chatId));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('online send → bubble upgraded to delivered with server id', () async {
    final fake = _FakeChatService();
    final c = _container(fake, online: true);
    addTearDown(c.dispose);

    await c.read(chatMessagesProvider('c1').notifier).addOutgoing('hi');

    expect(fake.sendCalls, 1);
    final q = _queue(c, 'c1');
    expect(q.length, 1);
    expect(q.single.status, MessageStatus.delivered);
    expect(q.single.id, _id(1));
  });

  test('online photo send upgrades to delivered image bubble', () async {
    final fake = _FakeChatService();
    final c = _container(fake, online: true);
    addTearDown(c.dispose);

    await c
        .read(chatMessagesProvider('c1').notifier)
        .addOutgoingPhoto(
          PickedChatImage(
            bytes: Uint8List.fromList([1, 2, 3]),
            mimeType: 'image/jpeg',
            fileName: 'photo.jpg',
          ),
          caption: 'look at this',
        );

    expect(fake.photoSendCalls, 1);
    expect(fake.attemptedPhotoCaptions, ['look at this']);
    final q = _queue(c, 'c1');
    expect(q.length, 1);
    expect(q.single.status, MessageStatus.delivered);
    expect(q.single.type, MessageType.image);
    expect(q.single.originalText, 'look at this');
    expect(q.single.attachment?.url, 'https://example.test/${_id(1)}.jpg');
  });

  test('online photo send without caption keeps an empty caption', () async {
    final fake = _FakeChatService();
    final c = _container(fake, online: true);
    addTearDown(c.dispose);

    await c
        .read(chatMessagesProvider('c1').notifier)
        .addOutgoingPhoto(
          PickedChatImage(
            bytes: Uint8List.fromList([4, 5, 6]),
            mimeType: 'image/png',
            fileName: 'no-caption.png',
          ),
        );

    expect(fake.photoSendCalls, 1);
    expect(fake.attemptedPhotoCaptions, ['']);
    final q = _queue(c, 'c1');
    expect(q.single.status, MessageStatus.delivered);
    expect(q.single.type, MessageType.image);
    expect(q.single.originalText, isEmpty);
    expect(q.single.attachment?.mimeType, 'image/png');
  });

  test('failed photo send can retry with same id and caption', () async {
    final fake = _FakeChatService()..throwOnSend = true;
    final c = _container(fake, online: true);
    addTearDown(c.dispose);

    await c
        .read(chatMessagesProvider('c1').notifier)
        .addOutgoingPhoto(
          PickedChatImage(
            bytes: Uint8List.fromList([7, 8, 9]),
            mimeType: 'image/jpeg',
            fileName: 'retry.jpg',
          ),
          caption: 'retry this photo',
        );

    final failed = _queue(c, 'c1').single;
    expect(fake.photoSendCalls, 1);
    expect(failed.status, MessageStatus.failed);
    expect(failed.type, MessageType.image);

    fake.throwOnSend = false;
    await c.read(chatMessagesProvider('c1').notifier).retryFailed(failed.id);

    final delivered = _queue(c, 'c1').single;
    expect(fake.photoSendCalls, 2);
    expect(fake.attemptedIds, [failed.id]);
    expect(fake.attemptedPhotoCaptions, ['retry this photo']);
    expect(delivered.status, MessageStatus.delivered);
    expect(delivered.id, failed.id);
    expect(delivered.attachment?.url, 'https://example.test/${failed.id}.jpg');
  });

  test('failed photo send can be deleted from the pending queue', () async {
    final fake = _FakeChatService()..throwOnSend = true;
    final c = _container(fake, online: true);
    addTearDown(c.dispose);

    await c
        .read(chatMessagesProvider('c1').notifier)
        .addOutgoingPhoto(
          PickedChatImage(
            bytes: Uint8List.fromList([10, 11, 12]),
            mimeType: 'image/jpeg',
            fileName: 'delete.jpg',
          ),
        );

    final failed = _queue(c, 'c1').single;
    expect(failed.status, MessageStatus.failed);

    c.read(chatMessagesProvider('c1').notifier).dropPending(failed.id);

    expect(_queue(c, 'c1'), isEmpty);
  });

  test('offline send stays queued (clock), no network hit', () async {
    final fake = _FakeChatService();
    final c = _container(fake, online: false);
    addTearDown(c.dispose);

    await c.read(chatMessagesProvider('c1').notifier).addOutgoing('hi');

    expect(fake.sendCalls, 0);
    final q = _queue(c, 'c1');
    expect(q.length, 1);
    expect(q.single.status, MessageStatus.pending);
  });

  test('online reply sends its stable target id', () async {
    final fake = _FakeChatService();
    final c = _container(fake, online: true);
    addTearDown(c.dispose);
    final source = Message(
      id: _id(99),
      chatId: 'c1',
      isOutgoing: false,
      originalText: 'source',
      translation: '',
      sentAt: DateTime.parse('2026-06-09T00:00:00Z'),
      status: MessageStatus.delivered,
    );

    await c
        .read(chatMessagesProvider('c1').notifier)
        .addOutgoing('reply', replyTo: source);

    expect(fake.attemptedReplyIds, [source.id]);
    expect(_queue(c, 'c1').single.replyTo?.id, source.id);
  });

  test('server error while online → bubble flips to failed', () async {
    final fake = _FakeChatService()..throwOnSend = true;
    final c = _container(fake, online: true);
    addTearDown(c.dispose);

    await c.read(chatMessagesProvider('c1').notifier).addOutgoing('hi');

    expect(fake.sendCalls, 1);
    final q = _queue(c, 'c1');
    expect(q.length, 1);
    expect(q.single.status, MessageStatus.failed);
  });

  test('unreachable backend leaves an online-interface send pending', () async {
    final fake = _FakeChatService()..throwOnSend = true;
    final c = _container(fake, online: true, backendReachable: false);
    addTearDown(c.dispose);

    await c.read(chatMessagesProvider('c1').notifier).addOutgoing('hi');

    expect(fake.sendCalls, 1);
    expect(_queue(c, 'c1').single.status, MessageStatus.pending);
  });

  test('removeMessage hides instantly; restore (undo) unhides', () async {
    final fake = _FakeChatService();
    final c = _container(fake, online: true);
    addTearDown(c.dispose);

    await c.read(chatMessagesProvider('c1').notifier).removeMessage('m1');
    expect(
      c.read(hiddenMessagesProvider('c1')),
      contains('m1'),
      reason: 'delete should hide the message without waiting for realtime',
    );

    await c.read(chatMessagesProvider('c1').notifier).restoreMessage('m1');
    expect(
      c.read(hiddenMessagesProvider('c1')),
      isNot(contains('m1')),
      reason: 'undo should bring it back',
    );
  });

  test(
    'dev failure switch fails once, disarms, and retry delivers same id',
    () async {
      final fake = _FakeChatService();
      final c = _container(fake, online: true);
      addTearDown(c.dispose);
      c.read(simulateFailureProvider.notifier).set(true);

      await c.read(chatMessagesProvider('c1').notifier).addOutgoing('hi');

      expect(fake.sendCalls, 0, reason: 'forced failure short-circuits send');
      final failed = _queue(c, 'c1').single;
      expect(failed.status, MessageStatus.failed);
      expect(c.read(simulateFailureProvider), isFalse);

      await c.read(chatMessagesProvider('c1').notifier).retryFailed(failed.id);

      expect(fake.sendCalls, 1);
      expect(fake.attemptedIds, [failed.id]);
      expect(_queue(c, 'c1').single.status, MessageStatus.delivered);
    },
  );

  test('flushPending is a no-op while offline', () async {
    final fake = _FakeChatService();
    final c = _container(fake, online: false);
    addTearDown(c.dispose);

    await c.read(chatMessagesProvider('c1').notifier).addOutgoing('hi');
    await c.read(chatMessagesProvider('c1').notifier).flushPending();

    expect(fake.sendCalls, 0);
    expect(_queue(c, 'c1').single.status, MessageStatus.pending);
  });

  test(
    'queued-while-offline send survives restart and flushes on reconnect',
    () async {
      // Session 1: offline. Enqueue a send; it persists to disk, never sent.
      final fake1 = _FakeChatService();
      final c1 = _container(fake1, online: false);
      await c1.read(chatMessagesProvider('c1').notifier).addOutgoing('hi');
      expect(fake1.sendCalls, 0);
      expect(_queue(c1, 'c1').single.status, MessageStatus.pending);
      // Let the async persist to disk finish before tearing the session down.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      c1.dispose();

      // Session 2 (simulated restart): same on-disk store, now online.
      final fake2 = _FakeChatService();
      final c2 = _container(fake2, online: true);
      addTearDown(c2.dispose);

      // Hydrate the queue from disk, then flush.
      c2.read(pendingSendsProvider('c1'));
      await Future<void>.delayed(Duration.zero);
      expect(
        _queue(c2, 'c1').single.status,
        MessageStatus.pending,
        reason: 'failed send should survive the restart',
      );

      await c2.read(chatMessagesProvider('c1').notifier).flushPending();

      expect(fake2.sendCalls, 1);
      expect(_queue(c2, 'c1').single.status, MessageStatus.delivered);
    },
  );

  test('offline reply preserves target id across restart and flush', () async {
    final source = Message(
      id: _id(98),
      chatId: 'c1',
      isOutgoing: false,
      originalText: 'persist me',
      translation: '',
      sentAt: DateTime.parse('2026-06-09T00:00:00Z'),
      status: MessageStatus.delivered,
    );
    final c1 = _container(_FakeChatService(), online: false);
    await c1
        .read(chatMessagesProvider('c1').notifier)
        .addOutgoing('queued reply', replyTo: source);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    c1.dispose();

    final fake2 = _FakeChatService();
    final c2 = _container(fake2, online: true);
    addTearDown(c2.dispose);
    c2.read(pendingSendsProvider('c1'));
    await Future<void>.delayed(Duration.zero);

    expect(_queue(c2, 'c1').single.replyTo?.id, source.id);
    await c2.read(chatMessagesProvider('c1').notifier).flushPending();
    expect(fake2.attemptedReplyIds, [source.id]);
  });

  test(
    'manual retry preserves the id after a committed response is lost',
    () async {
      final fake = _FakeChatService()..loseFirstResponse = true;
      final c = _container(fake, online: true);
      addTearDown(c.dispose);
      final source = Message(
        id: _id(97),
        chatId: 'c1',
        isOutgoing: false,
        originalText: 'retry target',
        translation: '',
        sentAt: DateTime.parse('2026-06-09T00:00:00Z'),
        status: MessageStatus.delivered,
      );

      await c
          .read(chatMessagesProvider('c1').notifier)
          .addOutgoing('once', replyTo: source);
      final failed = _queue(c, 'c1').single;
      expect(failed.status, MessageStatus.failed);

      await c.read(chatMessagesProvider('c1').notifier).retryFailed(failed.id);

      expect(_queue(c, 'c1').single.status, MessageStatus.delivered);
      expect(fake.attemptedIds, [failed.id, failed.id]);
      expect(fake.attemptedReplyIds, [source.id, source.id]);
      expect(fake.committedIds, {failed.id});
    },
  );

  test('same chat queues are isolated by account', () async {
    final alice = _container(
      _FakeChatService(),
      online: false,
      userId: 'user-a',
    );
    await alice
        .read(chatMessagesProvider('shared-chat').notifier)
        .addOutgoing('Alice private pending');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    alice.dispose();

    final bob = _container(_FakeChatService(), online: false, userId: 'user-b');
    bob.read(pendingSendsProvider('shared-chat'));
    await Future<void>.delayed(Duration.zero);
    expect(_queue(bob, 'shared-chat'), isEmpty);
    await bob
        .read(chatMessagesProvider('shared-chat').notifier)
        .addOutgoing('Bob private pending');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    bob.dispose();

    final aliceAgain = _container(
      _FakeChatService(),
      online: false,
      userId: 'user-a',
    );
    addTearDown(aliceAgain.dispose);
    aliceAgain.read(pendingSendsProvider('shared-chat'));
    await Future<void>.delayed(Duration.zero);
    expect(
      _queue(aliceAgain, 'shared-chat').map((message) => message.originalText),
      ['Alice private pending'],
    );
  });

  test('legacy and owner-mismatched queue payloads are discarded', () async {
    final aliceKey = pendingSendsStorageKey(userId: 'user-a', chatId: 'c1');
    SharedPreferences.setMockInitialValues({
      '${kPendingSendsKeyPrefix}c1': '[{"originalText":"legacy"}]',
      aliceKey: '{"ownerId":"user-b","messages":[]}',
    });
    final c = _container(_FakeChatService(), online: false);
    addTearDown(c.dispose);

    c.read(pendingSendsProvider('c1'));
    await Future<void>.delayed(Duration.zero);

    expect(_queue(c, 'c1'), isEmpty);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.containsKey('${kPendingSendsKeyPrefix}c1'), isFalse);
    expect(preferences.containsKey(aliceKey), isFalse);
  });

  test(
    'canonical reconciliation removes delivered plaintext from disk',
    () async {
      final c = _container(_FakeChatService(), online: false);
      addTearDown(c.dispose);
      await c.read(chatMessagesProvider('c1').notifier).addOutgoing('queued');
      final id = _queue(c, 'c1').single.id;
      await Future<void>.delayed(const Duration(milliseconds: 50));

      c.read(pendingSendsProvider('c1').notifier).reconcile([id]);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(_queue(c, 'c1'), isEmpty);
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(
        pendingSendsStorageKey(userId: 'user-a', chatId: 'c1'),
      );
      expect(raw, contains('"messages":[]'));
      expect(raw, isNot(contains('queued')));
    },
  );

  test('an immediate send merges with asynchronous disk hydration', () async {
    final key = pendingSendsStorageKey(userId: 'user-a', chatId: 'c1');
    SharedPreferences.setMockInitialValues({
      key:
          '{"ownerId":"user-a","messages":['
          '{"id":"${_id(9)}","chatId":"c1",'
          '"originalText":"from disk",'
          '"sentAt":"2026-06-09T00:00:00.000Z",'
          '"status":"pending",'
          '"replyToText":null,"replyToWasOutgoing":null}]}',
    });
    final c = _container(_FakeChatService(), online: false);
    addTearDown(c.dispose);

    await c
        .read(chatMessagesProvider('c1').notifier)
        .addOutgoing('new in memory');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(_queue(c, 'c1').map((message) => message.originalText), [
      'from disk',
      'new in memory',
    ]);
  });

  test('generated client message ids are distinct UUID v4 values', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final factory = c.read(clientMessageIdFactoryProvider);
    final first = factory();
    final second = factory();
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
      r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    expect(first, matches(uuidV4));
    expect(second, matches(uuidV4));
    expect(second, isNot(first));
  });
}
