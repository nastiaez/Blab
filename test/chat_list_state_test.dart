import 'dart:async';

import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/services/local_chat_history_cache.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/chat_list_state.dart';

class _FakeChatService implements ChatService {
  _FakeChatService(this.rows);
  final List<Map<String, dynamic>> rows;
  final _memberships = StreamController<List<Map<String, dynamic>>>.broadcast();
  final _messages = StreamController<void>.broadcast();
  final _translations = StreamController<void>.broadcast();

  @override
  Future<List<Map<String, dynamic>>> fetchChatList() async => rows;

  @override
  Stream<List<Map<String, dynamic>>> watchMyMemberships() =>
      _memberships.stream;

  @override
  Stream<void> watchChatListMessageChanges() => _messages.stream;

  @override
  Stream<void> watchChatListTranslationChanges() => _translations.stream;

  void emitMessageChange() => _messages.add(null);
  void emitTranslationChange() => _translations.add(null);

  // Unused in this test:
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StalledChatListService extends _FakeChatService {
  _StalledChatListService() : super(const []);

  @override
  Future<List<Map<String, dynamic>>> fetchChatList() =>
      Completer<List<Map<String, dynamic>>>().future;
}

class _SetupRefreshRaceService extends _FakeChatService {
  _SetupRefreshRaceService()
    : super([
        {
          'chat_id': 'new-chat',
          'needs_practice_language_selection': true,
          'my_learning': 'en',
        },
      ]);

  final stale = Completer<List<Map<String, dynamic>>>();
  int calls = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchChatList() async {
    if (++calls == 1) return rows;
    if (calls == 2) return stale.future;
    return [
      {
        'chat_id': 'new-chat',
        'needs_practice_language_selection': false,
        'my_learning': 'de',
        'last_body': 'Fresh message',
      },
    ];
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('successful setup survives a refresh started before the save', () async {
    final service = _SetupRefreshRaceService();
    final container = ProviderContainer(
      overrides: [chatServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    await container.read(chatListProvider.future);
    final notifier = container.read(chatListProvider.notifier);
    final staleRefresh = notifier.refresh();
    notifier.confirmPracticeLanguageSelection(
      'new-chat',
      kBlabLanguages.firstWhere((language) => language.code == 'de'),
    );
    expect(
      container
          .read(chatListProvider)
          .value!
          .single
          .needsPracticeLanguageSelection,
      isFalse,
    );
    final afterSave = notifier.refresh();
    service.stale.complete(service.rows);
    await Future.wait([staleRefresh, afterSave]);
    final chat = container.read(chatListProvider).value!.single;
    expect(chat.needsPracticeLanguageSelection, isFalse);
    expect(chat.learningLanguage.code, 'de');
    expect(chat.lastMessage, 'Fresh message');
  });

  test(
    'cached chats render before a stalled server request completes',
    () async {
      final cache = LocalChatHistoryCache('alice');
      final english = kBlabLanguages.firstWhere(
        (language) => language.code == 'en',
      );
      final german = kBlabLanguages.firstWhere(
        (language) => language.code == 'de',
      );
      await cache.saveChats([
        Chat(
          id: 'chat-1',
          partnerName: 'Bob',
          partnerInitial: 'B',
          learningLanguage: german,
          mode: ChatMode.practice,
          partnerNativeLanguage: german,
          partnerLearningLanguage: english,
          lastMessage: 'Cached hello',
          lastMessageTranslation: '',
          timestamp: DateTime.utc(2026, 8, 29, 12),
          unreadCount: 0,
        ),
      ]);
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('alice'),
          chatServiceProvider.overrideWithValue(_StalledChatListService()),
        ],
      );
      addTearDown(container.dispose);

      final chats = await container
          .read(chatListProvider.future)
          .timeout(const Duration(milliseconds: 500));

      expect(chats.single.partnerName, 'Bob');
      expect(chats.single.lastMessage, 'Cached hello');
    },
  );

  test(
    'new connection shares newest-activity priority and setup gates previews',
    () async {
      final fake = _FakeChatService([
        {'chat_id': 'older', 'last_at': '2026-09-01T12:00:00Z'},
        {
          'chat_id': 'new',
          'last_at': '2026-09-07T12:00:00Z',
          'needs_practice_language_selection': true,
          'last_body': 'Hallo',
          'last_practice_body': 'Hello',
        },
        {
          'chat_id': 'selected',
          'last_at': '2026-09-06T12:00:00Z',
          'last_body': 'Hallo',
          'last_practice_body': 'Hello',
        },
      ]);
      final container = ProviderContainer(
        overrides: [chatServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      final chats = await container.read(chatListProvider.future);
      expect(chats.map((chat) => chat.id), ['new', 'selected', 'older']);
      expect(chats.first.lastMessage, 'Hallo');
      expect(chats[1].lastMessage, 'Hello');
    },
  );

  test('maps chat_list rows to Chat tiles', () async {
    final fake = _FakeChatService([
      {
        'viewer_id': 'me',
        'chat_id': 'c1',
        'partner_id': 'u2',
        'partner_name': 'Aswin',
        'partner_avatar': null,
        'my_learning': 'ta',
        'partner_learning': 'uk',
        'last_body': 'hi',
        'last_at': '2026-05-30T12:00:00Z',
        'unread_count': 2,
        'my_mode': 'practice',
      },
    ]);
    final container = ProviderContainer(
      overrides: [chatServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final chats = await container.read(chatListProvider.future);
    expect(chats.length, 1);
    expect(chats.first.partnerName, 'Aswin');
    expect(chats.first.partnerInitial, 'A');
    expect(chats.first.unreadCount, 2);
    expect(chats.first.learningLanguage.code, 'ta');
    expect(chats.first.partnerLearningLanguage.code, 'uk');
    expect(chats.first.lastMessage, 'hi');
    expect(chats.first.mode, ChatMode.practice);
  });

  test('null my_mode defaults to practice', () async {
    final fake = _FakeChatService([
      {
        'viewer_id': 'me',
        'chat_id': 'c1',
        'partner_id': 'u2',
        'partner_name': 'Aswin',
        'partner_avatar': null,
        'my_learning': 'ta',
        'partner_learning': 'uk',
        'last_body': 'hi',
        'last_at': '2026-05-30T12:00:00Z',
        'unread_count': 2,
        'my_mode': null,
      },
    ]);
    final container = ProviderContainer(
      overrides: [chatServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    final chats = await container.read(chatListProvider.future);
    expect(chats.first.mode, ChatMode.practice);
  });

  test('empty rows → empty list', () async {
    final fake = _FakeChatService([]);
    final container = ProviderContainer(
      overrides: [chatServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    final chats = await container.read(chatListProvider.future);
    expect(chats, isEmpty);
  });

  test('incoming message changes refresh the chat-list preview', () async {
    final fake = _FakeChatService([
      {
        'viewer_id': 'me',
        'chat_id': 'c1',
        'partner_id': 'u2',
        'partner_name': 'Bob',
        'my_learning': 'de',
        'partner_learning': 'en',
        'last_body': 'before',
        'last_at': '2026-07-21T10:00:00Z',
        'unread_count': 0,
      },
    ]);
    final container = ProviderContainer(
      overrides: [chatServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    await container.read(chatListProvider.future);

    fake.rows.single['last_body'] = 'after';
    fake.rows.single['unread_count'] = 1;
    fake.emitMessageChange();

    final deadline = DateTime.now().add(const Duration(seconds: 1));
    while (container.read(chatListProvider).value?.single.lastMessage !=
            'after' &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final chat = container.read(chatListProvider).value!.single;
    expect(chat.lastMessage, 'after');
    expect(chat.unreadCount, 1);
  });

  test('translation changes refresh the chat-list preview', () async {
    final fake = _FakeChatService([
      {
        'viewer_id': 'me',
        'chat_id': 'c1',
        'partner_id': 'u2',
        'partner_name': 'Bob',
        'my_learning': 'de',
        'partner_learning': 'en',
        'last_body': 'before',
        'last_at': '2026-07-21T10:00:00Z',
        'unread_count': 0,
      },
    ]);
    final container = ProviderContainer(
      overrides: [chatServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    await container.read(chatListProvider.future);

    fake.rows.single['last_practice_body'] = 'after translation refresh';
    fake.emitTranslationChange();

    final deadline = DateTime.now().add(const Duration(seconds: 1));
    while (container.read(chatListProvider).value?.single.lastMessage !=
            'after translation refresh' &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(
      container.read(chatListProvider).value!.single.lastMessage,
      'after translation refresh',
    );
  });
}
