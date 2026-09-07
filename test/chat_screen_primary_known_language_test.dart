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
import 'dart:convert';

import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/features/chat/state/typing_state.dart';
import 'package:blab/features/chat/state/unread_chat_state.dart';
import 'package:blab/features/chat/widgets/message_interaction_target.dart';
import 'package:blab/features/chat/widgets/message_text.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/data/languages.dart';
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
import 'package:blab/shared/widgets/blab_icon.dart';
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
  _PrimaryKnownLanguageChatService({
    this.partnerName = 'Bob',
    this.learningLanguageCode = 'de',
    this.messageIsOutgoing = false,
    this.chatMode = 'normal',
    this.translationCutoffAt,
    this.preparedPackages = const [],
    this.languageTimeline = const [],
    this.messageText = 'Hallo',
    DateTime? messageSentAt,
    DateTime? previousMessageSentAt,
  }) : message = Message(
         id: 'msg-1',
         chatId: 'chat-1',
         isOutgoing: messageIsOutgoing,
         originalText: messageText,
         translation: '',
         sentAt: messageSentAt ?? DateTime.utc(2026, 8, 3, 12),
         status: MessageStatus.delivered,
       ),
       previousMessage = previousMessageSentAt == null
           ? null
           : Message(
               id: 'msg-0',
               chatId: 'chat-1',
               isOutgoing: true,
               originalText: 'Earlier',
               translation: '',
               sentAt: previousMessageSentAt,
               status: MessageStatus.delivered,
             );

  final String partnerName;
  final String learningLanguageCode;
  final bool messageIsOutgoing;
  final String chatMode;
  final DateTime? translationCutoffAt;
  final List<Map<String, dynamic>> preparedPackages;
  final List<Map<String, dynamic>> languageTimeline;
  final String messageText;
  int languageTimelineFetchCount = 0;

  final Message message;
  final Message? previousMessage;

  @override
  Future<List<Map<String, dynamic>>> fetchChatList() async => [
    {
      'chat_id': 'chat-1',
      'partner_id': 'bob',
      'partner_name': partnerName,
      'my_learning': learningLanguageCode,
      'partner_learning': 'en',
      'my_mode': chatMode,
      'translation_cutoff_at': translationCutoffAt?.toIso8601String(),
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
    return MessagePage(
      messages: previousMessage == null
          ? [message]
          : [previousMessage!, message],
      hasMore: false,
    );
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
  Future<List<Map<String, dynamic>>> fetchPreparedPackages({
    required String chatId,
    required List<String> messageIds,
  }) async => preparedPackages;

  @override
  Future<List<Map<String, dynamic>>> fetchLanguageTimeline(
    String chatId,
  ) async {
    languageTimelineFetchCount++;
    return languageTimeline;
  }

  @override
  Future<void> setLearningLanguage({
    required String chatId,
    required String langCode,
  }) async {}

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

ProviderContainer _containerForHeader(
  ChatService service, {
  List<Map<String, dynamic>> languageTimeline = const [],
  bool loadLanguageTimelineFromService = false,
  String primaryKnownLanguage = 'uk',
  List<String> knownLanguages = const ['uk'],
}) {
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
      if (!loadLanguageTimelineFromService)
        chatLanguageTimelineProvider.overrideWith(
          (ref, chatId) async => languageTimeline,
        ),
      currentProfileProvider.overrideWith(
        (_) async => UserProfile(
          displayName: 'Alice',
          interfaceLanguage: 'en',
          knownLanguages: knownLanguages,
          primaryKnownLanguage: primaryKnownLanguage,
        ),
      ),
    ],
  );
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

  testWidgets('chat header separates navigation, identity, and mode groups', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const partnerName = 'Alexandria Longlastname';
    final container = _containerForHeader(
      _PrimaryKnownLanguageChatService(partnerName: partnerName),
    );
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    final back = find.byWidgetPredicate(
      (widget) => widget is BlabIcon && widget.name == 'nav-arrow-left - 20',
    );
    final avatar = find.ancestor(
      of: find.text('AL'),
      matching: find.byWidgetPredicate((widget) {
        final decoration = widget is Container ? widget.decoration : null;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle;
      }),
    );
    final name = find.text(partnerName);
    final modeSwitch = find.byKey(const ValueKey('mode-toggle'));

    final backRect = tester.getRect(back);
    final avatarRect = tester.getRect(avatar);
    final nameRect = tester.getRect(name);
    final switchRect = tester.getRect(modeSwitch);

    expect(avatarRect.left - backRect.right, 10);
    expect(nameRect.left - avatarRect.right, 10);
    expect(switchRect.left - nameRect.right, 10);
  });

  testWidgets('chat header avatar and name use the approved treatment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = _containerForHeader(
      _PrimaryKnownLanguageChatService(partnerName: 'Bob Local'),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    final avatar = find.ancestor(
      of: find.text('BO'),
      matching: find.byWidgetPredicate((widget) {
        final decoration = widget is Container ? widget.decoration : null;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle;
      }),
    );
    final avatarRect = tester.getRect(avatar);
    final decoration =
        tester.widget<Container>(avatar).decoration! as BoxDecoration;
    final name = tester.widget<Text>(find.text('Bob Local'));

    expect(avatarRect.size, const Size.square(36));
    expect(decoration.color, const Color(0xFF46281C));
    expect(decoration.boxShadow, const [
      BoxShadow(color: Color(0x21231208), offset: Offset(0, 2), blurRadius: 4),
    ]);
    expect(name.style?.fontSize, 15);
    expect(name.style?.height, 1.2);
    expect(name.style?.fontWeight, FontWeight.w800);
    expect(name.style?.color, const Color(0xFF46281C));
    expect(
      tester.getSize(find.text('Bob Local')).width,
      greaterThanOrEqualTo(79),
    );
    expect(find.text('ONLINE'), findsNothing);
  });

  testWidgets('chat menu uses the approved warm preference treatment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = _containerForHeader(
      _PrimaryKnownLanguageChatService(
        partnerName: 'Bob Local',
        learningLanguageCode: 'uk',
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is BlabIcon && widget.name == 'more-vert - 20',
      ),
    );
    await tester.pump();

    final matchingSurfaces = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .where(
          (decoration) =>
              decoration.color == const Color(0xFFFFFCF8) &&
              decoration.border?.top.color == const Color(0xFFE1DAD2) &&
              decoration.borderRadius == BorderRadius.circular(14) &&
              decoration.boxShadow?.single ==
                  const BoxShadow(
                    color: Color(0x1A231208),
                    offset: Offset(0, 2),
                    blurRadius: 12,
                  ),
        );
    expect(matchingSurfaces, hasLength(1));

    final learningLabel = tester.widget<Text>(find.text('Learning language'));
    expect(learningLabel.style?.fontSize, 15);
    expect(learningLabel.style?.fontWeight, FontWeight.w400);
    expect(learningLabel.style?.color, const Color(0xFF46281C));

    final languageValue = tester.widget<Text>(find.text('Ukrainian'));
    expect(languageValue.style?.fontSize, 14);
    expect(languageValue.style?.fontWeight, FontWeight.w400);
    expect(languageValue.style?.color, const Color(0xFF917869));

    final menuRows = <Finder>[
      find.ancestor(
        of: find.text('Learning language'),
        matching: find.byType(InkWell),
      ),
      find.ancestor(
        of: find.text('Translation preferences'),
        matching: find.byType(InkWell),
      ),
    ];
    for (final row in menuRows) {
      expect(tester.getSize(row).height, 52);
    }

    final arrows = tester
        .widgetList<BlabIcon>(find.byType(BlabIcon))
        .where((icon) => icon.name == 'nav-arrow-right - 20');
    expect(arrows, hasLength(2));
    expect(
      arrows.every(
        (icon) => icon.size == 20 && icon.color == const Color(0xFF917869),
      ),
      isTrue,
    );
    final arrowFinder = find.byWidgetPredicate(
      (widget) => widget is BlabIcon && widget.name == 'nav-arrow-right - 20',
    );
    expect(
      tester.getRect(arrowFinder.at(0)).right,
      tester.getRect(arrowFinder.at(1)).right,
    );
  });

  testWidgets('date divider precedes and introduces a learning-language era', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sentAt = DateTime.now().subtract(const Duration(days: 1));
    final container = _containerForHeader(
      _PrimaryKnownLanguageChatService(
        learningLanguageCode: 'uk',
        messageIsOutgoing: true,
        messageSentAt: sentAt,
        previousMessageSentAt: sentAt.subtract(const Duration(days: 1)),
      ),
      languageTimeline: [
        {
          'revision': 2,
          'learning_language': 'uk',
          'created_at': sentAt
              .subtract(const Duration(minutes: 1))
              .toIso8601String(),
        },
      ],
    );
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    final previousBubbleRect = tester.getRect(
      find.ancestor(
        of: find.text('Earlier'),
        matching: find.byType(MessageInteractionTarget),
      ),
    );
    final dateRect = tester.getRect(find.text('Yesterday'));
    final languageRect = tester.getRect(find.text('Now learning Ukrainian'));
    final messageRect = tester.getRect(
      find.byType(MessageInteractionTarget).first,
    );

    expect(dateRect.top - previousBubbleRect.bottom, 18);
    expect(dateRect.top, lessThan(languageRect.top));
    expect(languageRect.top, lessThan(messageRect.top));
    expect(languageRect.top - dateRect.bottom, 10);
    expect(messageRect.top - languageRect.bottom, 10);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  testWidgets(
    'practice history keeps the completed language from its saved era',
    (tester) async {
      final sentAt = DateTime.utc(2026, 8, 28, 16, 11, 56);
      final cutoff = DateTime.utc(2026, 8, 29, 7, 40, 50);
      final timeline = [
        {
          'revision': 1,
          'learning_language': 'de',
          'created_at': DateTime.utc(2026, 8, 28, 10, 5).toIso8601String(),
        },
        {
          'revision': 2,
          'learning_language': 'uk',
          'created_at': DateTime.utc(2026, 8, 28, 16, 11, 45).toIso8601String(),
        },
        {
          'revision': 3,
          'learning_language': 'en',
          'created_at': DateTime.utc(2026, 8, 29, 7, 39, 38).toIso8601String(),
        },
        {
          'revision': 4,
          'learning_language': 'de',
          'created_at': cutoff.toIso8601String(),
        },
      ];
      final service = _PrimaryKnownLanguageChatService(
        learningLanguageCode: 'de',
        chatMode: 'practice',
        translationCutoffAt: cutoff,
        messageIsOutgoing: true,
        messageSentAt: sentAt,
        messageText: 'I went to school today',
        languageTimeline: timeline,
        preparedPackages: [
          {
            'message_id': 'msg-1',
            'chat_id': 'chat-1',
            'viewer_id': 'alice',
            'learning_language': 'uk',
            'primary_known_language': 'en',
            'language_revision': 2,
            'status': 'ready',
            'translation_text': 'Я сьогодні ходила до школи',
            'interface_text': 'I went to school today',
            'source_lang': 'en',
            'aid_mode': 'translation',
            'tokens': const <Map<String, dynamic>>[],
          },
        ],
      );
      final container = _containerForHeader(
        service,
        languageTimeline: timeline,
        primaryKnownLanguage: 'en',
        knownLanguages: const ['en'],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_host(container));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 3));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is MessageText &&
              widget.text == 'Я сьогодні ходила до школи',
        ),
        findsOneWidget,
      );
      expect(find.text('I went to school today'), findsNothing);
    },
  );

  testWidgets(
    'outgoing practice history updates after recovering a stale timeline',
    (tester) async {
      final sentAt = DateTime.utc(2026, 8, 28, 16, 11, 56);
      final fullTimeline = [
        {
          'revision': 1,
          'learning_language': 'de',
          'created_at': DateTime.utc(2026, 8, 28, 10, 5).toIso8601String(),
        },
        {
          'revision': 2,
          'learning_language': 'nl',
          'created_at': DateTime.utc(2026, 8, 28, 16, 12).toIso8601String(),
        },
      ];
      SharedPreferences.setMockInitialValues({
        'cached_language_timeline:alice:chat-1': jsonEncode([
          fullTimeline.last,
        ]),
      });
      final service = _PrimaryKnownLanguageChatService(
        learningLanguageCode: 'nl',
        chatMode: 'practice',
        messageIsOutgoing: true,
        messageSentAt: sentAt,
        messageText: 'Good morning, Alice!',
        languageTimeline: fullTimeline,
        preparedPackages: [
          {
            'message_id': 'msg-1',
            'chat_id': 'chat-1',
            'viewer_id': 'alice',
            'learning_language': 'de',
            'primary_known_language': 'en',
            'language_revision': 1,
            'status': 'ready',
            'translation_text': 'Guten Morgen, Alice!',
            'interface_text': 'Good morning, Alice!',
            'source_lang': 'en',
            'aid_mode': 'translation',
            'tokens': const <Map<String, dynamic>>[],
          },
          {
            'message_id': 'msg-1',
            'chat_id': 'chat-1',
            'viewer_id': 'alice',
            'learning_language': 'nl',
            'primary_known_language': 'en',
            'language_revision': 2,
            'status': 'ready',
            'translation_text': 'Goedemorgen, Alice!',
            'interface_text': 'Good morning, Alice!',
            'source_lang': 'en',
            'aid_mode': 'translation',
            'tokens': const <Map<String, dynamic>>[],
          },
        ],
      );
      final container = _containerForHeader(
        service,
        loadLanguageTimelineFromService: true,
        primaryKnownLanguage: 'en',
        knownLanguages: const ['en'],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_host(container));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 3));

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is MessageText && widget.text == 'Guten Morgen, Alice!',
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is MessageText &&
              widget.text == 'Goedemorgen, Alice!',
        ),
        findsNothing,
      );
    },
  );

  testWidgets('language marker keeps padding between message bubbles', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sentAt = DateTime.utc(2026, 8, 3, 12, 1);
    final container = _containerForHeader(
      _PrimaryKnownLanguageChatService(
        learningLanguageCode: 'uk',
        messageIsOutgoing: true,
        messageSentAt: sentAt,
        previousMessageSentAt: sentAt.subtract(const Duration(minutes: 1)),
      ),
      languageTimeline: [
        {
          'revision': 2,
          'learning_language': 'uk',
          'created_at': sentAt
              .subtract(const Duration(seconds: 30))
              .toIso8601String(),
        },
      ],
    );
    await tester.pumpWidget(_host(container));
    await _settle(tester);

    final previousBubbleRect = tester.getRect(
      find.ancestor(
        of: find.text('Earlier'),
        matching: find.byType(MessageInteractionTarget),
      ),
    );
    final markerRect = tester.getRect(find.text('Now learning Ukrainian'));
    final bubbleRects = [
      tester.getRect(find.byType(MessageInteractionTarget).at(0)),
      tester.getRect(find.byType(MessageInteractionTarget).at(1)),
    ]..sort((a, b) => a.top.compareTo(b.top));
    final currentBubbleRect = bubbleRects.last;

    expect(markerRect.top - previousBubbleRect.bottom, 10);
    expect(currentBubbleRect.top - markerRect.bottom, 10);

    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
  });

  test('saving a learning language refreshes its private timeline', () async {
    final service = _PrimaryKnownLanguageChatService(
      learningLanguageCode: 'uk',
      languageTimeline: [
        {
          'revision': 1,
          'learning_language': 'uk',
          'created_at': DateTime.utc(2026, 8, 28).toIso8601String(),
        },
      ],
    );
    final container = ProviderContainer(
      overrides: [
        chatServiceProvider.overrideWithValue(service),
        authSessionProvider.overrideWith((ref) => Stream.value(null)),
      ],
    );
    addTearDown(container.dispose);

    await container.read(chatListProvider.future);
    await container.read(chatLanguageTimelineProvider('chat-1').future);
    expect(service.languageTimelineFetchCount, 1);

    final german = kBlabLanguages.firstWhere((lang) => lang.code == 'de');
    await container
        .read(learningLanguageProvider('chat-1').notifier)
        .set(german);
    await container.read(chatLanguageTimelineProvider('chat-1').future);

    expect(service.languageTimelineFetchCount, 2);
  });

  test('avatar colors use only the refreshed palette', () {
    expect(BlabColors.avatarPalette, const [
      Color(0xFF46281C),
      Color(0xFF917869),
      Color(0xFFBC6C4E),
      Color(0xFF788C73),
      Color(0xFFAF787D),
      Color(0xFF5F3C4B),
    ]);
  });
}
