import 'dart:async';

import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Message _message(int number, {String? text}) => Message(
  id: 'm${number.toString().padLeft(3, '0')}',
  chatId: 'chat-1',
  isOutgoing: number.isEven,
  originalText: text ?? 'message $number',
  translation: '',
  sentAt: DateTime.utc(2026, 7, 19).add(Duration(seconds: number)),
  status: MessageStatus.delivered,
);

class _PaginationChatService implements ChatService {
  final changes = StreamController<MessageChange>.broadcast();
  final eventMessages = <String, Message>{};
  final requests = <({int limit, MessageCursor? before})>[];
  bool failOlder = false;

  List<Message> initial = List.generate(50, (i) => _message(i + 51));
  List<Message> older = List.generate(51, (i) => _message(i + 1));
  List<Message>? resync;

  MessageCursor _cursorFor(Message message) =>
      MessageCursor(createdAt: message.sentAt, id: message.id);

  @override
  Future<MessagePage> fetchMessagePage(
    String chatId, {
    int limit = 50,
    MessageCursor? before,
  }) async {
    requests.add((limit: limit, before: before));
    if (before != null) {
      if (failOlder) throw TimeoutException('offline');
      return MessagePage(
        messages: older,
        hasMore: false,
        nextCursor: _cursorFor(older.first),
      );
    }
    final page = resync ?? initial;
    return MessagePage(
      messages: page,
      hasMore: resync == null,
      nextCursor: _cursorFor(page.first),
    );
  }

  @override
  Stream<MessageChange> watchMessageChanges(String chatId) => changes.stream;

  @override
  Future<Message?> messageFromRealtimeRow(Map<String, dynamic> row) async {
    return eventMessages[row['id'] as String];
  }

  @override
  Stream<List<Map<String, dynamic>>> watchMyMemberships() =>
      const Stream.empty();

  @override
  Future<List<Map<String, dynamic>>> fetchChatList() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition was not reached');
}

({
  ProviderSubscription<AsyncValue<List<Message>>> subscription,
  Future<List<Message>> first,
})
_listenForMessages(ProviderContainer container) {
  final first = Completer<List<Message>>();
  final subscription = container.listen(chatMessagesProvider('chat-1'), (
    _,
    next,
  ) {
    if (!first.isCompleted && next.hasValue) first.complete(next.value!);
    if (!first.isCompleted && next.hasError) {
      first.completeError(next.error!, next.stackTrace!);
    }
  }, fireImmediately: true);
  return (subscription: subscription, first: first.future);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('loads older cursor page once and deduplicates the boundary', () async {
    final service = _PaginationChatService();
    final container = ProviderContainer(
      overrides: [
        chatServiceProvider.overrideWithValue(service),
        authSessionProvider.overrideWith((ref) => Stream.value(null)),
        currentUserIdProvider.overrideWithValue('user-a'),
      ],
    );
    final listener = _listenForMessages(container);
    addTearDown(() async {
      listener.subscription.close();
      container.dispose();
      await service.changes.close();
    });

    final initial = await listener.first;
    expect(initial, hasLength(50));
    expect(initial.first.id, 'm051');
    expect(container.read(chatPaginationProvider('chat-1')).hasMore, isTrue);

    service.failOlder = true;
    await container.read(chatMessagesProvider('chat-1').notifier).loadOlder();
    expect(container.read(chatMessagesProvider('chat-1')).value, hasLength(50));
    expect(container.read(chatPaginationProvider('chat-1')).hasMore, isTrue);

    service.failOlder = false;
    await container.read(chatMessagesProvider('chat-1').notifier).loadOlder();

    final loaded = container.read(chatMessagesProvider('chat-1')).value!;
    expect(loaded, hasLength(100));
    expect(loaded.first.id, 'm001');
    expect(loaded.last.id, 'm100');
    expect(loaded.map((m) => m.id).toSet(), hasLength(100));
    expect(service.requests, hasLength(3));
    expect(service.requests.last.before?.id, 'm051');
    await _waitFor(
      () => !container.read(chatPaginationProvider('chat-1')).hasMore,
    );
    expect(container.read(chatPaginationProvider('chat-1')).hasMore, isFalse);

    await container.read(chatMessagesProvider('chat-1').notifier).loadOlder();
    expect(service.requests, hasLength(3));
  });

  test(
    'merges realtime changes and replaces loaded window on resync',
    () async {
      final service = _PaginationChatService();
      final container = ProviderContainer(
        overrides: [
          chatServiceProvider.overrideWithValue(service),
          authSessionProvider.overrideWith((ref) => Stream.value(null)),
          currentUserIdProvider.overrideWithValue('user-a'),
        ],
      );
      final listener = _listenForMessages(container);
      addTearDown(() async {
        listener.subscription.close();
        container.dispose();
        await service.changes.close();
      });

      await listener.first;
      await Future<void>.delayed(Duration.zero);
      final inserted = _message(101, text: 'realtime');
      service.eventMessages[inserted.id] = inserted;
      service.changes.add(MessageChange.upsert({'id': inserted.id}));
      await _waitFor(
        () =>
            container.read(chatMessagesProvider('chat-1')).value?.last.id ==
            inserted.id,
      );
      expect(
        container.read(chatMessagesProvider('chat-1')).value!.last.id,
        inserted.id,
      );

      service.changes.add(const MessageChange.remove({'id': 'm075'}));
      await _waitFor(
        () => container
            .read(chatMessagesProvider('chat-1'))
            .value!
            .every((m) => m.id != 'm075'),
      );
      expect(
        container
            .read(chatMessagesProvider('chat-1'))
            .value!
            .where((m) => m.id == 'm075'),
        isEmpty,
      );

      service.resync = List.generate(50, (i) => _message(i + 52))
        ..add(inserted);
      service.changes.add(const MessageChange.resync());
      await _waitFor(
        () =>
            container.read(chatMessagesProvider('chat-1')).value?.first.id ==
            'm052',
      );
      final resynced = container.read(chatMessagesProvider('chat-1')).value!;
      expect(resynced.first.id, 'm052');
      expect(resynced.last.id, 'm101');
      expect(resynced.map((m) => m.id).toSet(), hasLength(resynced.length));
      expect(service.requests.last.before, isNull);
      expect(service.requests.last.limit, 50);
    },
  );
}
