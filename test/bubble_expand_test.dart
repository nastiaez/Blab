import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/features/chat/state/typing_state.dart';
import 'package:blab/features/chat/widgets/message_interaction_target.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/models/message_reaction.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/services/push_notification_gateway.dart';
import 'package:blab/shared/services/push_token_repository.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:blab/shared/state/privacy_settings.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:blab/shared/state/push_notifications_state.dart';
import 'package:blab/shared/widgets/blab_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Minimal fake covering only what a chat with a single, already-translated
/// message needs — everything else falls through to [noSuchMethod],
/// following the same convention as `reply_translation_preview_test.dart`.
/// Defaults to an incoming message in practice mode; pass `isOutgoing: true`
/// for the outgoing-bubble icon-side test, `mode: 'normal'` for the
/// no-icon-in-normal-mode test, or `text:` for a fixture whose learning-line
/// content should differ from the shared 'hallo' default (e.g. the TTS test,
/// which wants a multi-word sentence to prove the full line is spoken).
class _BubbleExpandChatService implements ChatService {
  _BubbleExpandChatService({
    bool isOutgoing = false,
    this.mode = 'practice',
    this.withReaction = false,
    String text = 'hallo',
    String? translatedText,
    this.sourceLang = 'de',
    this.partnerRead = false,
    this.translationFails = false,
    MessageStatus status = MessageStatus.delivered,
    DateTime? sentAt,
  }) : message = Message(
         id: isOutgoing ? 'outgoing-message' : 'incoming-message',
         chatId: 'chat-1',
         isOutgoing: isOutgoing,
         originalText: text,
         translation: '',
         sentAt: sentAt ?? DateTime.utc(2026, 8, 3, 12),
         status: status,
       ),
       _learningText = translatedText ?? text;

  final Message message;
  String mode;
  final bool withReaction;
  final String _learningText;
  final String sourceLang;
  final String interfaceText = 'hello';
  final bool partnerRead;
  final bool translationFails;
  final List<String> deletedMessageIds = [];

  @override
  Future<List<Map<String, dynamic>>> fetchChatList() async => [
    {
      'chat_id': 'chat-1',
      'partner_id': 'bob',
      'partner_name': 'Bob',
      'my_learning': 'de',
      'partner_learning': 'en',
      'my_mode': mode,
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
  Stream<List<Map<String, dynamic>>> watchReads(String chatId) => partnerRead
      ? Stream.value([
          {'message_id': message.id, 'user_id': 'bob', 'receipt_visible': true},
        ])
      : Stream.value(const []);

  @override
  Future<CachedMessageTranslation?> fetchCachedTranslation({
    required String messageId,
    required String targetLang,
    required String interfaceLang,
  }) async {
    if (messageId != message.id) return null;
    if (translationFails) return null;
    return (
      text: _learningText,
      interfaceText: interfaceText,
      interfaceLang: interfaceLang,
      sourceLang: sourceLang,
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
  Future<List<Map<String, dynamic>>> fetchMessageReactions(
    String chatId,
  ) async => withReaction
      ? [
          {
            'message_id': message.id,
            'user_id': 'alice',
            'emoji': '❤️',
            'created_at': '2026-08-03T12:01:00Z',
          },
        ]
      : const [];

  @override
  Stream<MessageReactionChange> watchMessageReactionChanges(String chatId) =>
      const Stream.empty();

  @override
  Future<void> setChatMode({
    required String chatId,
    required ChatMode mode,
  }) async {
    this.mode = mode.name;
  }

  @override
  Future<void> softDelete(String messageId) async {
    deletedMessageIds.add(messageId);
  }

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

/// Stand-in [TtsService] that records `speak` calls instead of hitting
/// platform channels — lets the "play full sentence" test (finding #6)
/// assert exactly what text/language the speaker icon requested.
class _RecordingTtsService implements TtsService {
  final List<(String text, String languageCode)> spokenCalls = [];

  @override
  Future<bool> isLanguageAvailable(String languageCode) async => true;

  @override
  Future<void> speak(String text, String languageCode) async {
    spokenCalls.add((text, languageCode));
  }

  @override
  Future<void> stop() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _buildContainer(ChatService service, {TtsService? tts}) {
  // Default to a recording fake (never a real platform-channel TtsService)
  // so every test in this file stays free of MissingPluginException, even
  // ones that don't care about the speak calls.
  final resolvedTts = tts ?? _RecordingTtsService();
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
      // Finding #1/#5 (final whole-branch review): the translation pipeline
      // now targets the reader's primary known language, not
      // profiles.interface_language, and gates every request on this
      // provider having actually resolved. Every fixture in this file needs
      // a resolved profile for translations to fire at all.
      currentProfileProvider.overrideWith(
        (_) async => const UserProfile(
          displayName: 'Alice',
          interfaceLanguage: 'en',
          knownLanguages: ['en'],
          primaryKnownLanguage: 'en',
        ),
      ),
      ttsServiceProvider.overrideWithValue(resolvedTts),
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

Future<BoxDecoration> _reactionDecoration(
  WidgetTester tester, {
  required String mode,
  required bool isOutgoing,
}) async {
  final container = _buildContainer(
    _BubbleExpandChatService(
      isOutgoing: isOutgoing,
      mode: mode,
      withReaction: true,
    ),
  );
  await tester.pumpWidget(_host(container));
  await _settle(tester);

  final badge = find.byKey(const ValueKey('my-reaction-❤️'));
  final decoration = tester
      .widgetList<Container>(
        find.descendant(of: badge, matching: find.byType(Container)),
      )
      .map((container) => container.decoration)
      .whereType<BoxDecoration>()
      .singleWhere((decoration) => decoration.shape == BoxShape.circle);

  await tester.pumpWidget(const SizedBox.shrink());
  container.dispose();
  return decoration;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets(
    'short Practice bubbles hug their text instead of sharing a minimum width',
    (tester) async {
      Future<double> bubbleWidth(String text) async {
        final container = _buildContainer(
          _BubbleExpandChatService(isOutgoing: true, text: text),
        );
        await tester.pumpWidget(_host(container));
        await _settle(tester);

        final width = tester
            .getSize(
              find.byKey(const ValueKey('bubble-content-outgoing-message')),
            )
            .width;

        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        return width;
      }

      final shortWidth = await bubbleWidth('Hi');
      final mediumWidth = await bubbleWidth('Hello, this is longer');

      expect(shortWidth, lessThan(mediumWidth));
    },
  );

  testWidgets('date labels sit directly on the chat background', (
    tester,
  ) async {
    final container = _buildContainer(_BubbleExpandChatService());
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    final label = tester.element(find.text('Aug 3'));
    var hasPillBackground = false;
    label.visitAncestorElements((ancestor) {
      if (ancestor.widget is Center) return false;
      final widget = ancestor.widget;
      if (widget is Container) {
        final decoration = widget.decoration;
        if (widget.color != null ||
            decoration is BoxDecoration && decoration.color != null) {
          hasPillBackground = true;
        }
      }
      return true;
    });

    expect(hasPillBackground, isFalse);
  });

  testWidgets(
    'reaction badges sit on the inner edge of incoming and outgoing bubbles',
    (tester) async {
      Future<({Rect badge, Rect bubble})> geometry(bool isOutgoing) async {
        final service = _BubbleExpandChatService(
          isOutgoing: isOutgoing,
          mode: 'normal',
          withReaction: true,
        );
        final container = _buildContainer(service);
        await tester.pumpWidget(_host(container));
        await _settle(tester);

        final geometry = (
          badge: tester.getRect(find.byKey(const ValueKey('my-reaction-❤️'))),
          bubble: tester.getRect(
            find.byKey(
              ValueKey(
                'bubble-content-${isOutgoing ? 'outgoing-message' : 'incoming-message'}',
              ),
            ),
          ),
        );

        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        return geometry;
      }

      final incoming = await geometry(false);
      final outgoing = await geometry(true);

      expect(incoming.badge.center.dx, greaterThan(incoming.bubble.center.dx));
      expect(outgoing.badge.center.dx, lessThan(outgoing.bubble.center.dx));
    },
  );

  testWidgets('reaction badges use the neutral surface in both directions', (
    tester,
  ) async {
    for (final isOutgoing in [false, true]) {
      final decoration = await _reactionDecoration(
        tester,
        mode: 'practice',
        isOutgoing: isOutgoing,
      );

      expect(decoration.color, const Color(0xFFFFFCF8));
      expect((decoration.border! as Border).top.color, const Color(0xFFDCD2C8));
    }
  });

  testWidgets('reaction badges cast a shadow only in Practice mode', (
    tester,
  ) async {
    final normal = await _reactionDecoration(
      tester,
      mode: 'normal',
      isOutgoing: true,
    );
    final practice = await _reactionDecoration(
      tester,
      mode: 'practice',
      isOutgoing: true,
    );

    expect(normal.boxShadow, isNull);
    expect(practice.boxShadow, isNotEmpty);
  });

  testWidgets('accepted outgoing message uses one gray check', (tester) async {
    final container = _buildContainer(
      _BubbleExpandChatService(isOutgoing: true),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    final icons = tester.widgetList<BlabIcon>(find.byType(BlabIcon)).toList();
    expect(icons.where((icon) => icon.name == 'check - 16'), hasLength(1));
    expect(icons.where((icon) => icon.name == 'double-check - 16'), isEmpty);
  });

  testWidgets('read outgoing message uses two gray checks', (tester) async {
    final container = _buildContainer(
      _BubbleExpandChatService(isOutgoing: true, partnerRead: true),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    final icon = tester
        .widgetList<BlabIcon>(find.byType(BlabIcon))
        .singleWhere((icon) => icon.name == 'double-check - 16');
    expect(icon.color.a, closeTo(0.5, 0.001));
    expect(icon.color.r, closeTo(const Color(0xFF231208).r, 0.001));
  });

  testWidgets('delivery failure is a text-only row below the bubble', (
    tester,
  ) async {
    final container = _buildContainer(
      _BubbleExpandChatService(isOutgoing: true, status: MessageStatus.failed),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    final status = find.byKey(const ValueKey('failed-message-retry'));
    final bubble = find.byKey(
      const ValueKey('bubble-content-outgoing-message'),
    );
    expect(find.text('Not sent · Tap to try again'), findsOneWidget);
    expect(
      tester.getRect(status).top,
      greaterThanOrEqualTo(tester.getRect(bubble).bottom),
    );
    final statusText = tester.widget<Text>(
      find.text('Not sent · Tap to try again'),
    );
    expect(statusText.textAlign, TextAlign.right);
    expect(statusText.style?.fontWeight, FontWeight.w500);
    expect(
      tester
          .widgetList<BlabIcon>(find.byType(BlabIcon))
          .where((icon) => icon.name == 'refresh - 16'),
      isEmpty,
    );
  });

  testWidgets('translation failure is a text-only row below the bubble', (
    tester,
  ) async {
    final container = _buildContainer(
      _BubbleExpandChatService(translationFails: true),
    );
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    final status = find.byKey(const ValueKey('translation-message-retry'));
    final bubble = find.byKey(
      const ValueKey('bubble-content-incoming-message'),
    );
    expect(find.text('Couldn’t translate · Retry'), findsOneWidget);
    expect(
      tester.getRect(status).top,
      greaterThanOrEqualTo(tester.getRect(bubble).bottom),
    );
    final statusText = tester.widget<Text>(
      find.text('Couldn’t translate · Retry'),
    );
    expect(statusText.textAlign, TextAlign.left);
    expect(statusText.style?.fontWeight, FontWeight.w500);
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets('unsupported source shows a neutral hint without retry', (
    tester,
  ) async {
    final container = _buildContainer(
      _BubbleExpandChatService(sourceLang: 'other', text: '你好'),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    expect(
      find.text('Blab doesn’t speak this one yet — try German.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('translation-message-retry')),
      findsNothing,
    );
    final hint = tester.widget<Text>(
      find.text('Blab doesn’t speak this one yet — try German.'),
    );
    expect(hint.style?.fontSize, 12);
    expect(hint.style?.fontWeight, FontWeight.w400);
    expect(hint.style?.color, const Color(0xFF917869));
    expect(find.text('Hallo'), findsNothing);
  });

  testWidgets('no message-adjacent language controls remain', (tester) async {
    final container = _buildContainer(_BubbleExpandChatService());
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    expect(find.byKey(const ValueKey('translate-icon')), findsNothing);
    expect(find.byKey(const ValueKey('play-sentence-icon')), findsNothing);
    expect(find.byKey(const ValueKey('collapse-icon')), findsNothing);
  });

  testWidgets('Practice long press reveals known-language text and Listen', (
    tester,
  ) async {
    final container = _buildContainer(
      _BubbleExpandChatService(text: 'hallo mein freund'),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    expect(find.text('hello'), findsNothing);
    await tester.longPress(find.byType(MessageInteractionTarget));
    await tester.pumpAndSettle();

    expect(find.text('hello'), findsOneWidget);
    expect(find.byKey(const ValueKey('message-action-listen')), findsOneWidget);
    expect(find.byKey(const ValueKey('message-action-original')), findsNothing);
    await _settle(tester);
  });

  testWidgets('Practice Listen speaks the primary visible sentence', (
    tester,
  ) async {
    final tts = _RecordingTtsService();
    final container = _buildContainer(
      _BubbleExpandChatService(text: 'hallo mein freund'),
      tts: tts,
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    await tester.longPress(find.byType(MessageInteractionTarget));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('message-action-listen')));
    await tester.pumpAndSettle();

    expect(tts.spokenCalls, hasLength(1));
    expect(tts.spokenCalls.single, ('hallo mein freund', 'de'));
    await _settle(tester);
  });

  testWidgets('Normal Original toggles the exact authored second line', (
    tester,
  ) async {
    final container = _buildContainer(
      _BubbleExpandChatService(
        mode: 'normal',
        text: 'hallo',
        translatedText: 'hello translated',
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    expect(find.text('hallo'), findsNothing);
    await tester.longPress(find.byType(MessageInteractionTarget));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('message-action-original')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('message-action-original')));
    await tester.pumpAndSettle();
    expect(find.text('hallo'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('message-action-original')));
    await tester.pumpAndSettle();
    expect(find.text('hallo'), findsNothing);
    await _settle(tester);
  });

  testWidgets('Reply stores the primary visible text and opens the composer', (
    tester,
  ) async {
    final container = _buildContainer(
      _BubbleExpandChatService(
        text: 'authored text',
        translatedText: 'visible text',
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    await tester.longPress(find.byType(MessageInteractionTarget));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('message-action-reply')));
    await tester.pumpAndSettle();

    expect(
      container.read(replyingToProvider('chat-1'))?.originalText,
      'visible text',
    );
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await _settle(tester);
  });

  testWidgets('Edit uses exact authored text and hides the media action', (
    tester,
  ) async {
    final container = _buildContainer(
      _BubbleExpandChatService(
        isOutgoing: true,
        text: 'exact authored text',
        translatedText: 'visible translation',
        sentAt: DateTime.now().toUtc(),
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    await tester.longPress(find.byType(MessageInteractionTarget));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('message-action-edit')));
    await tester.pumpAndSettle();

    expect(find.text('Edit message'), findsOneWidget);
    expect(find.byKey(const ValueKey('composer-attach-button')), findsNothing);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('composer-message-text-field')),
          )
          .controller!
          .text,
      'exact authored text',
    );
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await _settle(tester);
  });

  testWidgets('Delete confirms and removes without Undo', (tester) async {
    final service = _BubbleExpandChatService(isOutgoing: true);
    final container = _buildContainer(service);
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    await tester.longPress(find.byType(MessageInteractionTarget));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('message-action-delete')));
    await tester.pumpAndSettle();

    expect(find.text('Delete message?'), findsOneWidget);
    expect(
      find.text(
        'Are you sure you want to delete this message? It will also be deleted for Bob.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(service.deletedMessageIds, ['outgoing-message']);
    expect(find.text('Undo'), findsNothing);
    await _settle(tester);
  });

  testWidgets('long press keeps the message viewport height stable', (
    tester,
  ) async {
    final container = _buildContainer(_BubbleExpandChatService());
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    final before = tester.getSize(find.byType(ListView).first).height;

    await tester.longPress(find.byType(MessageInteractionTarget));
    await tester.pumpAndSettle();

    final after = tester.getSize(find.byType(ListView).first).height;
    expect(after, before);
    await _settle(tester);
  });

  testWidgets('normal mode has no translate/play-sentence icon', (
    tester,
  ) async {
    final container = _buildContainer(_BubbleExpandChatService(mode: 'normal'));
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    expect(find.byKey(const ValueKey('translate-icon')), findsNothing);
    expect(find.byKey(const ValueKey('play-sentence-icon')), findsNothing);
  });

  testWidgets('first mode-switch tap dismisses selection', (tester) async {
    final container = _buildContainer(_BubbleExpandChatService());
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    await tester.longPress(find.byType(MessageInteractionTarget));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('message-action-listen')), findsOneWidget);

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('mode-toggle'))),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('message-action-listen')), findsNothing);
    expect(container.read(chatModeProvider('chat-1')), ChatMode.practice);
    await _settle(tester);
  });

  testWidgets('dismissed reaction row finishes its fade before removal', (
    tester,
  ) async {
    final container = _buildContainer(_BubbleExpandChatService());
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    await tester.longPress(find.byType(MessageInteractionTarget));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('floating-reaction-container-opacity')),
      findsOneWidget,
    );

    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('mode-toggle'))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    final fading = tester.widget<FadeTransition>(
      find.byKey(const ValueKey('floating-reaction-container-opacity')),
    );
    expect(fading.opacity.value, closeTo(0.5, 0.08));

    await tester.pump(const Duration(milliseconds: 76));
    expect(
      find.byKey(const ValueKey('floating-reaction-container-opacity')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('message-action-listen')), findsNothing);
    await _settle(tester);
  });

  testWidgets('swiping open chat background does not change mode', (
    tester,
  ) async {
    final container = _buildContainer(_BubbleExpandChatService());
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    final listRect = tester.getRect(find.byType(ListView).first);
    await tester.dragFrom(
      Offset(listRect.center.dx, listRect.top + 40),
      const Offset(-100, 0),
    );
    await _settle(tester);

    expect(container.read(chatModeProvider('chat-1')), ChatMode.practice);
    expect(container.read(replyingToProvider('chat-1')), isNull);
  });

  testWidgets('swiping the empty left side of an outgoing row replies', (
    tester,
  ) async {
    final container = _buildContainer(
      _BubbleExpandChatService(isOutgoing: true),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    final listRect = tester.getRect(find.byType(ListView).first);
    final bubbleRect = tester.getRect(
      find.byKey(const ValueKey('bubble-content-outgoing-message')),
    );
    await tester.dragFrom(
      Offset(listRect.left + 20, bubbleRect.center.dy),
      const Offset(100, 0),
    );
    await _settle(tester);

    expect(
      container.read(replyingToProvider('chat-1'))?.id,
      'outgoing-message',
    );
    expect(container.read(chatModeProvider('chat-1')), ChatMode.practice);
  });

  testWidgets('a diagonal upward gesture on a message row does not reply', (
    tester,
  ) async {
    final container = _buildContainer(
      _BubbleExpandChatService(isOutgoing: true),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    final listRect = tester.getRect(find.byType(ListView).first);
    final bubbleRect = tester.getRect(
      find.byKey(const ValueKey('bubble-content-outgoing-message')),
    );
    await tester.dragFrom(
      Offset(listRect.left + 20, bubbleRect.center.dy),
      const Offset(100, -75),
    );
    await _settle(tester);

    expect(container.read(replyingToProvider('chat-1')), isNull);
  });

  testWidgets('swiping the empty right side of an incoming row replies', (
    tester,
  ) async {
    final container = _buildContainer(_BubbleExpandChatService());
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    final listRect = tester.getRect(find.byType(ListView).first);
    final bubbleRect = tester.getRect(
      find.byKey(const ValueKey('bubble-content-incoming-message')),
    );
    await tester.dragFrom(
      Offset(listRect.right - 20, bubbleRect.center.dy),
      const Offset(100, 0),
    );
    await _settle(tester);

    expect(
      container.read(replyingToProvider('chat-1'))?.id,
      'incoming-message',
    );
    expect(container.read(chatModeProvider('chat-1')), ChatMode.practice);
  });

  testWidgets('swiping a bubble still replies without changing the mode', (
    tester,
  ) async {
    final container = _buildContainer(_BubbleExpandChatService());
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    await tester.drag(
      find.byType(MessageInteractionTarget),
      const Offset(-100, 0),
    );
    await _settle(tester);

    expect(container.read(replyingToProvider('chat-1')), isNotNull);
    expect(container.read(chatModeProvider('chat-1')), ChatMode.practice);
  });
}
