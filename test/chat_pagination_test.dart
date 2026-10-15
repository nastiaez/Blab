import 'dart:async';

import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/data/languages.dart';
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
  bool failEvent = false;
  int failRecent = 0;

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
    if (failRecent > 0) {
      failRecent--;
      throw TimeoutException('recovery temporarily unavailable');
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
    if (failEvent) throw TimeoutException('event enrichment failed');
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
  for (var attempt = 0; attempt < 200; attempt++) {
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

class _ControlledChatList extends ChatListNotifier {
  @override
  Future<List<Chat>> build() async => const [];
  void announce(String id, {String chatId = 'chat-1'}) {
    final lang = kBlabLanguages.first;
    state = AsyncData([
      Chat(
        id: chatId,
        partnerName: 'Partner',
        partnerInitial: 'P',
        learningLanguage: lang,
        mode: ChatMode.practice,
        partnerNativeLanguage: lang,
        partnerLearningLanguage: lang,
        lastMessage: 'incoming',
        lastMessageTranslation: '',
        lastMessageId: id,
        timestamp: DateTime.now(),
        unreadCount: 1,
      ),
    ]);
  }
}

void main() {
  test(
    'recovery is chat-scoped, retries reads and stops after catch-up',
    () async {
      final service = _PaginationChatService();
      final list = _ControlledChatList();
      final container = ProviderContainer(
        overrides: [
          chatServiceProvider.overrideWithValue(service),
          chatListProvider.overrideWith(() => list),
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
      await container.read(chatListProvider.future);
      await container.read(chatMessagesProvider('chat-1').notifier).loadOlder();
      final baseline = service.requests.length;
      list.announce('m101', chatId: 'another-chat');
      await Future<void>.delayed(const Duration(milliseconds: 250));
      expect(service.requests.length, baseline);
      service.initial = [...service.initial, _message(101)];
      service.failRecent = 1;
      list.announce('m101');
      await _waitFor(
        () =>
            container.read(chatMessagesProvider('chat-1')).value?.last.id ==
            'm101',
      );
      expect(
        container.read(chatMessagesProvider('chat-1')).value,
        hasLength(101),
      );
      expect(service.requests.length, baseline + 2);
      list.announce('m101');
      await Future<void>.delayed(const Duration(milliseconds: 450));
      expect(service.requests.length, baseline + 2);
    },
  );

  test('disposing a chat cancels scheduled catch-up', () async {
    final service = _PaginationChatService();
    final list = _ControlledChatList();
    final container = ProviderContainer(
      overrides: [
        chatServiceProvider.overrideWithValue(service),
        chatListProvider.overrideWith(() => list),
        authSessionProvider.overrideWith((ref) => Stream.value(null)),
        currentUserIdProvider.overrideWithValue('user-a'),
      ],
    );
    final listener = _listenForMessages(container);
    await listener.first;
    await container.read(chatListProvider.future);
    list.announce('m101');
    listener.subscription.close();
    container.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(service.requests, hasLength(1));
    await service.changes.close();
  });

  for (final failure in ['missing event', 'failed enrichment']) {
    test('recovers $failure without leaving the conversation', () async {
      final service = _PaginationChatService();
      final list = _ControlledChatList();
      final container = ProviderContainer(
        overrides: [
          chatServiceProvider.overrideWithValue(service),
          chatListProvider.overrideWith(() => list),
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
      await container.read(chatListProvider.future);
      await Future<void>.delayed(Duration.zero);
      service.initial = [...service.initial, _message(101)];
      if (failure == 'missing event') {
        list.announce(
          'm101',
        ); // Independent preview updated; no timeline event.
      } else {
        service.failEvent = true;
        service.changes.add(const MessageChange.upsert({'id': 'm101'}));
      }
      await _waitFor(
        () =>
            container.read(chatMessagesProvider('chat-1')).value?.last.id ==
            'm101',
      );
      expect(
        container
            .read(chatMessagesProvider('chat-1'))
            .value!
            .map((m) => m.id)
            .toSet(),
        hasLength(51),
      );
    });
  }

  test(
    'notification refresh merges latest messages without discarding older history',
    () async {
      SharedPreferences.setMockInitialValues({});
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
      await container.read(chatMessagesProvider('chat-1').notifier).loadOlder();
      service.initial = [...service.initial, _message(101)];
      await container
          .read(chatMessagesProvider('chat-1').notifier)
          .refreshRecent();
      final rows = container.read(chatMessagesProvider('chat-1')).value!;
      expect(rows.first.id, 'm001');
      expect(rows.last.id, 'm101');
      expect(rows, hasLength(101));
    },
  );

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
