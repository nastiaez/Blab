import 'dart:async';

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

class _ReplyPreviewChatService implements ChatService {
  _ReplyPreviewChatService();

  @override
  Future<List<Map<String, dynamic>>> fetchLanguageTimeline(
    String chatId,
  ) async => [
    {
      'chat_id': chatId,
      'user_id': 'alice',
      'revision': 1,
      'learning_language': 'ta',
      'created_at': DateTime.utc(2026, 8, 3, 11).toIso8601String(),
    },
  ];

  final source = Message(
    id: 'source-message',
    chatId: 'chat-1',
    isOutgoing: true,
    originalText: 'Are you coming today?',
    translation: '',
    sentAt: DateTime.utc(2026, 8, 3, 12),
    status: MessageStatus.delivered,
  );

  late final reply = Message(
    id: 'reply-message',
    chatId: 'chat-1',
    isOutgoing: false,
    originalText: 'Yes',
    translation: '',
    sentAt: DateTime.utc(2026, 8, 3, 12, 1),
    status: MessageStatus.delivered,
    replyTo: source,
  );

  @override
  Future<List<Map<String, dynamic>>> fetchChatList() async => [
    {
      'chat_id': 'chat-1',
      'partner_id': 'bob',
      'partner_name': 'Bob',
      'my_learning': 'ta',
      'partner_learning': 'en',
      'last_body': 'Yes',
      'last_at': reply.sentAt.toIso8601String(),
      'last_message_id': reply.id,
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
    return MessagePage(messages: [reply], hasMore: false);
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
    return _translationFor(messageId, interfaceLang);
  }

  CachedMessageTranslation? _translationFor(
    String messageId,
    String interfaceLang,
  ) {
    if (messageId == source.id) {
      return (
        text: 'இன்று வருகிறாயா?',
        interfaceText: source.originalText,
        interfaceLang: interfaceLang,
        sourceLang: 'en',
        mode: 'translation',
        explanation: null,
        confidence: null,
        tokens: <Map<String, dynamic>>[],
      );
    }
    if (messageId == reply.id) {
      return (
        text: 'ஆம்.',
        interfaceText: reply.originalText,
        interfaceLang: interfaceLang,
        sourceLang: 'en',
        mode: 'translation',
        explanation: null,
        confidence: null,
        tokens: <Map<String, dynamic>>[],
      );
    }
    return null;
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
      final translation = _translationFor(id, interfaceLang);
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

Widget _host(ChatService service, {TranslateMessageFn? translateMessage}) {
  return ProviderScope(
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
      translateMessageFnProvider.overrideWithValue(
        translateMessage ??
            (messageId) async {
              throw MessageTranslationFailed('unexpected_live_translation');
            },
      ),
      typingTransportProvider('chat-1').overrideWithValue(_NoopTyping()),
      // Finding #1/#5 (final whole-branch review): the translation pipeline
      // now targets the reader's primary known language and gates every
      // request on this provider having resolved — without an override it
      // never resolves in a test container, so no translation would fire.
      currentProfileProvider.overrideWith(
        (_) async => const UserProfile(
          displayName: 'Alice',
          interfaceLanguage: 'en',
          knownLanguages: ['en'],
          primaryKnownLanguage: 'en',
        ),
      ),
    ],
    child: const MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: ChatScreen(chatId: 'chat-1'),
    ),
  );
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('reply quote preview uses cached translation when available', (
    tester,
  ) async {
    final service = _ReplyPreviewChatService();
    var liveTranslationCalls = 0;
    await tester.pumpWidget(
      _host(
        service,
        translateMessage: (messageId) async {
          liveTranslationCalls++;
          throw MessageTranslationFailed('unexpected_live_translation');
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('ஆம்'), findsOneWidget);
    expect(find.text('இன்று வருகிறாயா?'), findsOneWidget);
    expect(liveTranslationCalls, 0);
  });

  testWidgets('translated reply quote does not overflow at mobile width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_host(_ReplyPreviewChatService()));
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final exception = tester.takeException();
    expect(exception, isNull);
  });

  testWidgets('swiping a delivered message starts reply mode', (tester) async {
    await tester.pumpWidget(_host(_ReplyPreviewChatService()));
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.drag(find.text('ஆம்'), const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(find.text('Replying to Bob'), findsNothing);
    expect(find.text('Bob'), findsWidgets);
    expect(find.text('Yes'), findsWidgets);
  });
}
