import 'dart:async';

import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/features/chat/state/pending_sends_state.dart';
import 'package:blab/features/chat/state/typing_state.dart';
import 'package:blab/features/chat/state/unread_chat_state.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/services/local_chat_history_cache.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/services/push_notification_gateway.dart';
import 'package:blab/shared/services/push_token_repository.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:blab/shared/state/privacy_settings.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:blab/shared/state/push_notifications_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _StalledHistoryService implements ChatService {
  @override
  Future<MessagePage> fetchMessagePage(
    String chatId, {
    int limit = 50,
    MessageCursor? before,
  }) => Completer<MessagePage>().future;

  @override
  Stream<MessageChange> watchMessageChanges(String chatId) =>
      const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RetryingHistoryService implements ChatService {
  int historyFetches = 0;
  int liveWatches = 0;

  final message = Message(
    id: 'message-after-retry',
    chatId: 'chat-1',
    isOutgoing: false,
    originalText: 'Loaded after retry',
    translation: '',
    sentAt: DateTime.utc(2026, 9, 12, 12),
    status: MessageStatus.delivered,
  );

  @override
  Future<List<Map<String, dynamic>>> fetchChatList() async => [
    {
      'chat_id': 'chat-1',
      'partner_id': 'bob',
      'partner_name': 'Bob',
      'my_learning': 'de',
      'partner_learning': 'en',
      'my_mode': 'normal',
      'last_body': message.originalText,
      'last_at': message.sentAt.toIso8601String(),
      'last_message_id': message.id,
      'unread_count': 0,
    },
  ];

  @override
  Stream<List<Map<String, dynamic>>> watchMyMemberships() =>
      const Stream.empty();

  @override
  Stream<void> watchChatListMessageChanges() => const Stream.empty();

  @override
  Stream<void> watchChatListTranslationChanges() => const Stream.empty();

  @override
  Future<MessagePage> fetchMessagePage(
    String chatId, {
    int limit = 50,
    MessageCursor? before,
  }) async {
    historyFetches++;
    if (historyFetches == 1) throw StateError('initial history failed');
    return MessagePage(messages: [message], hasMore: false);
  }

  @override
  Stream<MessageChange> watchMessageChanges(String chatId) {
    liveWatches++;
    return const Stream.empty();
  }

  @override
  Future<CachedMessageTranslation?> fetchCachedTranslation({
    required String messageId,
    required String targetLang,
    required String interfaceLang,
  }) async => (
    text: message.originalText,
    interfaceText: message.originalText,
    interfaceLang: interfaceLang,
    sourceLang: 'en',
    mode: 'none',
    explanation: null,
    confidence: null,
    tokens: <Map<String, dynamic>>[],
  );

  @override
  Future<Map<String, CachedMessageTranslation>>
  fetchCachedTranslationsForMessages({
    required List<String> messageIds,
    required String targetLang,
    required String interfaceLang,
  }) async => {
    for (final id in messageIds)
      id: (
        text: message.originalText,
        interfaceText: message.originalText,
        interfaceLang: interfaceLang,
        sourceLang: 'en',
        mode: 'none',
        explanation: null,
        confidence: null,
        tokens: <Map<String, dynamic>>[],
      ),
  };

  @override
  Stream<MessageTranslationChange> watchMessageTranslationChanges({
    required String targetLang,
    required String interfaceLang,
  }) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControlledFailingHistoryService extends _StalledHistoryService {
  final requestStarted = Completer<void>();
  final releaseFailure = Completer<void>();
  final failureCompleted = Completer<void>();
  final liveWatchStarted = Completer<void>();

  @override
  Future<MessagePage> fetchMessagePage(
    String chatId, {
    int limit = 50,
    MessageCursor? before,
  }) async {
    requestStarted.complete();
    try {
      await releaseFailure.future;
      throw StateError('history refresh failed');
    } finally {
      failureCompleted.complete();
    }
  }

  @override
  Stream<MessageChange> watchMessageChanges(String chatId) {
    liveWatchStarted.complete();
    return const Stream.empty();
  }
}

class _UnsupportedPushGateway implements PushNotificationGateway {
  @override
  bool get isSupported => false;

  @override
  Future<PushAuthorizationStatus> authorizationStatus() async =>
      PushAuthorizationStatus.unavailable;

  @override
  Future<PushAuthorizationStatus> requestPermission() async =>
      PushAuthorizationStatus.unavailable;

  @override
  Future<String?> getToken() async => null;

  @override
  Stream<String> get onTokenRefresh => const Stream.empty();

  @override
  Future<void> deleteToken() async {}

  @override
  Future<PushOpenEvent?> initialOpenEvent() async => null;

  @override
  Stream<PushOpenEvent> get onOpenEvent => const Stream.empty();

  @override
  Future<void> openSystemSettings() async {}
}

class _NoopPushTokenRepository implements PushTokenRepository {
  @override
  Future<void> register({
    required String token,
    required bool previewsEnabled,
  }) async {}

  @override
  Future<void> unregister(String token) async {}
}

class _NoopTyping implements TypingTransport {
  @override
  String get localUserId => 'alice';

  @override
  Stream<TypingEvent> get events => const Stream.empty();

  @override
  Future<void> send(bool isTyping) async {}

  @override
  Future<void> close() async {}
}

ProviderContainer _chatScreenContainer(ChatService service) {
  return ProviderContainer(
    overrides: [
      chatServiceProvider.overrideWithValue(service),
      authSessionProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('alice'),
      isOnlineProvider.overrideWithValue(false),
      typingIndicatorsEnabledProvider.overrideWithValue(false),
      pushNotificationGatewayProvider.overrideWithValue(
        _UnsupportedPushGateway(),
      ),
      pushTokenRepositoryProvider.overrideWithValue(_NoopPushTokenRepository()),
      translateMessageFnProvider.overrideWithValue((messageId) async {
        throw MessageTranslationFailed('unexpected_live_translation');
      }),
      typingTransportProvider('chat-1').overrideWithValue(_NoopTyping()),
      chatLanguageTimelineProvider.overrideWith(
        (ref, chatId) async => const [],
      ),
      chatUnreadMessageIdsProvider.overrideWith(
        (ref, chatId) async => const [],
      ),
      currentProfileProvider.overrideWith(
        (_) async => const UserProfile(
          displayName: 'Alice',
          interfaceLanguage: 'en',
          knownLanguages: ['en'],
          primaryKnownLanguage: 'en',
        ),
      ),
    ],
  );
}

Widget _chatScreenHost(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: ChatScreen(chatId: 'chat-1'),
    ),
  );
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 25));
  }
  fail('Timed out waiting for ${finder.describeMatch(Plurality.one)}');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets(
    'failed initial history can retry and establish the live message watch',
    (tester) async {
      final service = _RetryingHistoryService();
      final container = _chatScreenContainer(service);

      await tester.pumpWidget(_chatScreenHost(container));
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('chat-history-retry')),
      );

      expect(find.text("Couldn't load messages"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(service.historyFetches, 1);
      expect(service.liveWatches, 0);

      await tester.tap(find.byKey(const ValueKey('chat-history-retry')));
      await _pumpUntilFound(tester, find.text('Loaded after retry'));

      expect(service.historyFetches, 2);
      expect(service.liveWatches, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
      await tester.pump(const Duration(milliseconds: 300));
    },
  );

  testWidgets('uncached history error disables the composer and send action', (
    tester,
  ) async {
    final service = _RetryingHistoryService();
    final container = _chatScreenContainer(service);

    await tester.pumpWidget(_chatScreenHost(container));
    final textField = find.byKey(const ValueKey('composer-message-text-field'));
    await _pumpUntilFound(tester, textField);
    await tester.enterText(textField, 'Must stay visible');
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('chat-history-retry')),
    );

    expect(tester.widget<TextField>(textField).enabled, isFalse);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('composer-attach-button')),
          )
          .onPressed,
      isNull,
    );
    final sendAction = find.descendant(
      of: find.byKey(const ValueKey('composer-send-decoration')),
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(sendAction).onTap, isNull);
    await tester.tap(
      find.byKey(const ValueKey('composer-send-icon')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(container.read(pendingSendsProvider('chat-1')), isEmpty);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  test(
    'cached messages render before a stalled history request completes',
    () async {
      final cache = LocalChatHistoryCache('alice');
      await cache.saveMessages('chat-1', [
        Message(
          id: 'message-1',
          chatId: 'chat-1',
          isOutgoing: false,
          originalText: 'Cached message',
          translation: '',
          sentAt: DateTime.utc(2026, 8, 29, 12),
          status: MessageStatus.delivered,
        ),
      ]);
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('alice'),
          chatServiceProvider.overrideWithValue(_StalledHistoryService()),
        ],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(
        chatMessagesProvider('chat-1'),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final deadline = DateTime.now().add(const Duration(milliseconds: 500));
      while (container.read(chatMessagesProvider('chat-1')).value == null &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final messages = container.read(chatMessagesProvider('chat-1')).value!;

      expect(messages.single.originalText, 'Cached message');
    },
  );

  test('cached messages stay readable when history refresh fails', () async {
    final cache = LocalChatHistoryCache('alice');
    await cache.saveMessages('chat-1', [
      Message(
        id: 'message-1',
        chatId: 'chat-1',
        isOutgoing: false,
        originalText: 'Cached message',
        translation: '',
        sentAt: DateTime.utc(2026, 8, 29, 12),
        status: MessageStatus.delivered,
      ),
    ]);
    final service = _ControlledFailingHistoryService();
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWithValue('alice'),
        chatServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    final subscription = container.listen(
      chatMessagesProvider('chat-1'),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await service.requestStarted.future;
    service.releaseFailure.complete();
    await service.failureCompleted.future;
    await service.liveWatchStarted.future;

    final state = container.read(chatMessagesProvider('chat-1'));
    expect(state.hasError, isFalse);
    expect(state.requireValue.single.originalText, 'Cached message');
  });
}
