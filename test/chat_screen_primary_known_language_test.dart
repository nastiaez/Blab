// Final whole-branch review, finding #1 (CRITICAL): the migration computes
// the server's `interfaceLang` slot as the reader's *primary known
// language* (falling back to `profiles.interface_language` only when unset)
// — not `profiles.interface_language` itself. The client used to thread
// `profiles.interface_language` into the translation pipeline's cache keys
// and DB queries regardless, so a reader whose primary known language
// differs from their interface language (the feature's own motivating
// case — see docs/superpowers/specs/2026-08-11-modes-known-languages-design.md
// § Problem) would never get a cache hit and would trip the client's own
// `interface_language_changed` staleness check.
//
// This test is the regression guard the final review specifically asked
// for: every other fixture in this branch left `primaryKnownLanguage` at
// its default (equal to `interfaceLanguage`), which is exactly why this bug
// shipped through 12 task reviews undetected.
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/features/chat/state/typing_state.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/services/chat_service.dart';
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

/// Reader: interface language English, but primary known language Ukrainian
/// (exactly Nastia's case in the design spec's Problem section — interface
/// English, chats natively in Ukrainian). Chat mode is normal, so the
/// translation target is the reader's *primary known language* (FR-23) —
/// here that must be 'uk', not the account's interface language 'en'.
class _PrimaryKnownLanguageChatService implements ChatService {
  final message = Message(
    id: 'msg-1',
    chatId: 'chat-1',
    isOutgoing: false,
    originalText: 'Hallo',
    translation: '',
    sentAt: DateTime.utc(2026, 8, 3, 12),
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
    // The regression under test: the client used to send `targetLang: 'de'`
    // (the chat's *learning* language — wrong for normal mode, see finding
    // #5) and/or `interfaceLang: 'en'` (profiles.interface_language — wrong
    // per finding #1) here. Only the correct pairing — both 'uk', the
    // reader's primary known language — returns a hit, so a regression
    // shows up as a permanently-missing translation rather than a subtly
    // wrong one.
    if (messageId != message.id ||
        targetLang != 'uk' ||
        interfaceLang != 'uk') {
      return null;
    }
    return (
      text: 'Привіт',
      interfaceText: 'Привіт',
      interfaceLang: 'uk',
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
    'normal mode targets the primary known language, not the interface '
    'language, for cache lookups',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          chatServiceProvider.overrideWithValue(
            _PrimaryKnownLanguageChatService(),
          ),
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
          // The crux of the test: primary known language ('uk') differs
          // from the account's interface language ('en').
          currentProfileProvider.overrideWith(
            (_) async => const UserProfile(
              displayName: 'Alice',
              interfaceLanguage: 'en',
              knownLanguages: ['uk'],
              primaryKnownLanguage: 'uk',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(_host(container));
      await _settle(tester);

      // Normal mode + unknown source ('de' isn't on the ['uk'] known list)
      // → translation only, targeting primary known language 'uk'. This
      // only renders if the client asked the fake service for exactly
      // (targetLang: 'uk', interfaceLang: 'uk') — the pre-fix code would
      // have asked for (targetLang: 'de', interfaceLang: 'en') instead and
      // gotten a permanent cache miss.
      expect(find.text('Привіт'), findsOneWidget);
      expect(find.text('Hallo'), findsNothing);
    },
  );
}
