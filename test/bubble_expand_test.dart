import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/features/chat/state/typing_state.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:blab/shared/services/push_notification_gateway.dart';
import 'package:blab/shared/services/push_token_repository.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:blab/shared/state/privacy_settings.dart';
import 'package:blab/shared/state/push_notifications_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Minimal fake covering only what a practice-mode chat with a single,
/// already-translated message needs — everything else falls through to
/// [noSuchMethod], following the same convention as
/// `reply_translation_preview_test.dart`. Defaults to an incoming message;
/// pass `isOutgoing: true` for the outgoing-bubble icon-side test.
class _BubbleExpandChatService implements ChatService {
  _BubbleExpandChatService({bool isOutgoing = false})
    : message = Message(
        id: isOutgoing ? 'outgoing-message' : 'incoming-message',
        chatId: 'chat-1',
        isOutgoing: isOutgoing,
        originalText: 'hallo',
        translation: '',
        sentAt: DateTime.utc(2026, 8, 3, 12),
        status: MessageStatus.delivered,
      );

  final Message message;

  @override
  Future<List<Map<String, dynamic>>> fetchChatList() async => [
    {
      'chat_id': 'chat-1',
      'partner_id': 'bob',
      'partner_name': 'Bob',
      'my_learning': 'de',
      'partner_learning': 'en',
      'my_mode': 'practice',
      'last_body': 'hallo',
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
    return MessagePage(messages: [message], hasMore: false);
  }

  @override
  Stream<MessageChange> watchMessageChanges(String chatId) =>
      const Stream.empty();

  @override
  Future<CachedMessageTranslation?> fetchCachedTranslation({
    required String messageId,
    required String targetLang,
    required String interfaceLang,
  }) async {
    if (messageId != message.id) return null;
    return (
      text: 'hallo',
      interfaceText: 'hello',
      interfaceLang: interfaceLang,
      sourceLang: 'de',
      mode: 'translation',
      explanation: null,
      confidence: null,
      tokens: <Map<String, dynamic>>[],
    );
  }

  @override
  Future<Map<String, CachedMessageTranslation>>
  fetchCachedTranslationsForMessages({
    required List<String> messageIds,
    required String targetLang,
    required String interfaceLang,
  }) async {
    final result = <String, CachedMessageTranslation>{};
    for (final id in messageIds) {
      final translation = await fetchCachedTranslation(
        messageId: id,
        targetLang: targetLang,
        interfaceLang: interfaceLang,
      );
      if (translation != null) result[id] = translation;
    }
    return result;
  }

  @override
  Stream<MessageTranslationChange> watchMessageTranslationChanges({
    required String targetLang,
    required String interfaceLang,
  }) => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

ProviderContainer _buildContainer(ChatService service) {
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
      pushTokenRepositoryProvider.overrideWithValue(
        _NoopPushTokenRepository(),
      ),
      translateMessageFnProvider.overrideWithValue((messageId) async {
        throw MessageTranslationFailed('unexpected_live_translation');
      }),
      typingTransportProvider('chat-1').overrideWithValue(_NoopTyping()),
    ],
  );
}

Widget _host(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: ChatScreen(chatId: 'chat-1'),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets(
    'tapping the translate icon expands the second lane and swaps the icon',
    (tester) async {
      final container = _buildContainer(_BubbleExpandChatService());
      addTearDown(container.dispose);
      await tester.pumpWidget(_host(container));
      await _settle(tester);

      expect(find.byKey(const ValueKey('translate-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('play-sentence-icon')), findsNothing);
      expect(find.text('hello'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('translate-icon')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('translate-icon')), findsNothing);
      expect(find.byKey(const ValueKey('play-sentence-icon')), findsOneWidget);
      expect(find.text('hello'), findsOneWidget);

      // Tapping the swapped icon collapses it back.
      await tester.tap(find.byKey(const ValueKey('play-sentence-icon')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('translate-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('play-sentence-icon')), findsNothing);
      expect(find.text('hello'), findsNothing);

      // Expanding/collapsing changes the bubble's height, which re-fires the
      // VisibilityDetector and can (re)schedule MessageReadsNotifier's 250ms
      // read-receipt debounce timer (unrelated to this task) — drain it so
      // it doesn't outlive the test.
      await _settle(tester);
    },
  );

  testWidgets(
    'the icon sits on the side toward the screen center for an incoming bubble',
    (tester) async {
      final container = _buildContainer(_BubbleExpandChatService());
      addTearDown(container.dispose);
      await tester.pumpWidget(_host(container));
      await _settle(tester);

      // The test message is incoming (left-aligned), so the icon — toward
      // the screen's horizontal center — must sit to its right.
      final iconRect = tester.getRect(
        find.byKey(const ValueKey('translate-icon')),
      );
      final bubbleRect = tester.getRect(
        find.byKey(const ValueKey('bubble-content-incoming-message')),
      );

      expect(iconRect.left, greaterThanOrEqualTo(bubbleRect.right));
    },
  );

  testWidgets(
    'the icon sits on the side toward the screen center for an outgoing bubble',
    (tester) async {
      final container = _buildContainer(
        _BubbleExpandChatService(isOutgoing: true),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(_host(container));
      await _settle(tester);

      // The test message is outgoing (right-aligned), so the icon — toward
      // the screen's horizontal center — must sit to its left.
      final iconRect = tester.getRect(
        find.byKey(const ValueKey('translate-icon')),
      );
      final bubbleRect = tester.getRect(
        find.byKey(const ValueKey('bubble-content-outgoing-message')),
      );

      expect(iconRect.right, lessThanOrEqualTo(bubbleRect.left));
    },
  );

  testWidgets('switching mode collapses an expanded message', (tester) async {
    final container = _buildContainer(_BubbleExpandChatService());
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    await tester.tap(find.byKey(const ValueKey('translate-icon')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('play-sentence-icon')), findsOneWidget);

    container.read(chatModeResetSignalProvider('chat-1').notifier).bump();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('translate-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('play-sentence-icon')), findsNothing);

    // Drain any read-receipt debounce timer re-armed by the expand/collapse
    // layout changes above (unrelated to this task) so it doesn't outlive
    // the test.
    await _settle(tester);
  });
}
