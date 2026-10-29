import 'package:flutter/services.dart';
// ignore_for_file: unused_import, unused_element, unused_element_parameter, prefer_interpolation_to_compose_strings, curly_braces_in_flow_control_structures
import 'package:blab/features/invite/test_access_gate.dart';
import 'package:blab/features/auth/auth_screen.dart';
import 'package:blab/features/onboarding/onboarding_bootstrap_screen.dart';
import 'package:blab/features/invite/invite_continuation.dart';
import 'package:blab/shared/data/app_channel.dart';
import 'package:blab/features/chat/state/message_reactions_state.dart';
import 'package:blab/shared/models/message_reaction.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:blab/app/router.dart';
import 'package:blab/shared/widgets/offline_banner.dart';
import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/features/onboarding/state/onboarding_destination_state.dart';
import 'package:blab/features/onboarding/state/onboarding_destination.dart';
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
import 'dart:async';
import 'package:integration_test/integration_test.dart';
import 'package:blab/features/chat/widgets/anchored_message_panels.dart';
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
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/features/chat/widgets/word_popup.dart';
import 'package:blab/shared/models/chat.dart';
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
import 'package:go_router/go_router.dart';
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
    this.pending = false,
    this.needsPracticeLanguageSelection = false,
    this.learningLanguageCode = 'de',
    this.messageIsOutgoing = false,
    bool languagesMatchedAtSend = false,
    this.chatMode = 'normal',
    this.translationCutoffAt,
    this.groupAiStartedAt,
    this.messageType = MessageType.text,
    this.messageSenderName,
    String? messageSenderId,
    String? previousMessageSenderId,
    this.preparedPackages = const [],
    this.languageTimeline = const [],
    this.messageText = 'Hallo',
    this.previousMessageIsOutgoing = true,
    this.previousMessageText = 'Earlier',
    DateTime? messageSentAt,
    DateTime? previousMessageSentAt,
  }) : message = Message(
         id: 'msg-1',
         chatId: 'chat-1',
         isOutgoing: messageIsOutgoing,
         languagesMatchedAtSend: languagesMatchedAtSend,
         type: messageType,
         senderName: messageSenderName,
         senderId: messageSenderId,
         originalText: messageText,
         translation: '',
         sentAt: messageSentAt ?? DateTime.utc(2026, 8, 3, 12),
         status: MessageStatus.delivered,
       ),
       previousMessage = previousMessageSentAt == null
           ? null
           : Message(
               id: 'msg-0',
               senderName: messageSenderName,
               senderId: previousMessageSenderId ?? messageSenderId,
               chatId: 'chat-1',
               isOutgoing: previousMessageIsOutgoing,
               originalText: previousMessageText,
               translation: '',
               sentAt: previousMessageSentAt,
               status: MessageStatus.delivered,
             );

  final bool pending;
  @override
  Future<bool> isMessageTranslationPending({
    required String messageId,
    required String targetLang,
    required String interfaceLang,
  }) async => pending;

  final bool needsPracticeLanguageSelection;
  final String partnerName;
  final String learningLanguageCode;
  final bool messageIsOutgoing;
  String chatMode;
  final DateTime? translationCutoffAt;
  final DateTime? groupAiStartedAt;
  final MessageType messageType;
  final String? messageSenderName;
  final List<Map<String, dynamic>> preparedPackages;
  final List<Map<String, dynamic>> languageTimeline;
  final String messageText;
  final bool previousMessageIsOutgoing;
  final String previousMessageText;
  int languageTimelineFetchCount = 0;

  final Message message;
  final Message? previousMessage;

  @override
  Future<List<Map<String, dynamic>>> fetchChatList() async => [
    {
      'needs_practice_language_selection': needsPracticeLanguageSelection,
      'chat_id': 'chat-1',
      'partner_id': 'bob',
      'partner_name': partnerName,
      'my_learning': learningLanguageCode,
      'partner_learning': 'en',
      'my_mode': chatMode,
      'translation_cutoff_at': translationCutoffAt?.toIso8601String(),
      if (groupAiStartedAt != null) 'chat_kind': 'group',
      'ai_started_at': groupAiStartedAt?.toIso8601String(),
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
  Future<void> setChatMode({
    required String chatId,
    required ChatMode mode,
  }) async {
    chatMode = mode.name;
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

Widget _host(
  ProviderContainer container, {
  bool disableAnimations = false,
  bool accessibleNavigation = false,
  Locale? locale,
  ThemeData? theme,
  double textScale = 1,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: locale,
      theme: theme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
            accessibleNavigation: accessibleNavigation,
          ),
          child: const ChatScreen(chatId: 'chat-1'),
        ),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 30,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for ${finder.describeMatch(Plurality.one)}');
}

ProviderContainer _containerForHeader(
  ChatService service, {
  List<Map<String, dynamic>> languageTimeline = const [],
  List<String> unreadMessageIds = const [],
  bool loadLanguageTimelineFromService = false,
  String primaryKnownLanguage = 'uk',
  List<String> knownLanguages = const ['uk'],
  bool isOnline = false,
  Future<MessageTranslation> Function(String messageId)? translate,
  TargetedTranslateMessageFn? retryTranslate,
  Future<Map<String, dynamic>> Function()? accessCheck,
  EmailAuthAction? emailAuth,
  Future<OnboardingDestination> Function()? resolveDestination,
}) {
  return ProviderContainer(
    overrides: [
      if (emailAuth != null)
        emailAuthActionProvider.overrideWithValue(emailAuth),
      chatServiceProvider.overrideWithValue(service),
      onboardingDestinationProvider.overrideWith(
        (_) async => resolveDestination == null
            ? OnboardingDestination.chats
            : resolveDestination(),
      ),
      authSessionProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('alice'),
      isOnlineProvider.overrideWithValue(isOnline),
      onlineProvider.overrideWith((_) => Stream.value(isOnline)),
      if (accessCheck != null)
        testAccessCheckProvider.overrideWithValue(accessCheck),
      typingIndicatorsEnabledProvider.overrideWithValue(false),
      pushNotificationGatewayProvider.overrideWithValue(
        _UnsupportedPushGateway(),
      ),
      pushTokenRepositoryProvider.overrideWithValue(_NoopPushTokenRepository()),
      translateMessageFnProvider.overrideWithValue((
        messageId, {
        targetLang,
      }) async {
        if (translate != null) return translate(messageId);
        throw MessageTranslationFailed('unexpected_live_translation');
      }),
      if (retryTranslate != null)
        retryMessageFnProvider.overrideWithValue(retryTranslate),
      typingTransportProvider('chat-1').overrideWithValue(_NoopTyping()),
      if (!loadLanguageTimelineFromService)
        chatLanguageTimelineProvider.overrideWith(
          (ref, chatId) async => languageTimeline,
        ),
      chatUnreadMessageIdsProvider.overrideWith(
        (ref, chatId) async => unreadMessageIds,
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

class _ReviewService extends _PrimaryKnownLanguageChatService {
  _ReviewService({
    required bool outgoing,
    required String mode,
    this.long = false,
  }) : super(
         chatMode: mode,
         messageIsOutgoing: outgoing,
         messageSentAt: DateTime.now().toUtc().subtract(
           const Duration(minutes: 4),
         ),
         messageText: long
             ? 'On Saturday I would like to go to the market early and buy fresh vegetables. Afterwards we will meet at the little café next to the park. If the weather stays nice, we can take a long walk along the river. I will bring a blanket and something to eat. Perhaps we will find a quiet spot under the trees. In the afternoon we can visit the new museum you mentioned last week. Please tell me whether you would rather come by bike or by tram. You do not have to hurry and can stop for a break along the way. For dinner I would like to cook something simple together. Afterwards we can talk about our week and plan our next outing.'
             : 'Allons nous promener dans le parc demain.',
         previousMessageSentAt: DateTime.now().toUtc().subtract(
           const Duration(minutes: 5),
         ),
         previousMessageText: 'Earlier in our conversation.',
       );
  final bool long;
  @override
  Future<MessagePage> fetchMessagePage(
    String chatId, {
    MessageCursor? before,
    int limit = 50,
  }) async => MessagePage(
    hasMore: false,
    messages: [
      if (!long && previousMessage != null) previousMessage!,
      message,
      if (!long && !message.isOutgoing)
        ...List.generate(
          4,
          (i) => Message(
            id: 'later-$i',
            chatId: 'chat-1',
            translation: '',
            status: MessageStatus.delivered,
            senderId: i.isEven ? 'me' : 'them',
            originalText: message.originalText,
            isOutgoing: i.isEven,
            sentAt: message.sentAt.add(Duration(seconds: i + 1)),
          ),
        ),
    ],
  );
  @override
  Future<CachedMessageTranslation?> fetchCachedTranslation({
    required String messageId,
    required String targetLang,
    required String interfaceLang,
  }) async => (
    text: long
        ? 'Am Samstag möchte ich früh zum Markt gehen und frisches Gemüse kaufen. Danach treffen wir uns am kleinen Café neben dem Park. Wenn das Wetter schön bleibt, können wir einen langen Spaziergang am Fluss machen. Ich bringe eine Decke und etwas zu essen mit. Vielleicht finden wir einen ruhigen Platz unter den Bäumen. Am Nachmittag können wir das neue Museum besuchen, über das du letzte Woche gesprochen hast. Bitte sag mir, ob du lieber mit dem Fahrrad oder mit der Straßenbahn kommen möchtest. Wir müssen uns nicht beeilen und können unterwegs immer wieder eine Pause machen. Zum Abendessen würde ich gern etwas Einfaches zusammen kochen. Danach erzählen wir uns von unserer Woche und planen den nächsten Ausflug.'
        : 'Lass uns morgen durch den Park spazieren.',
    interfaceText: long
        ? message.originalText
        : 'Let’s walk through the park tomorrow.',
    interfaceLang: interfaceLang,
    sourceLang: 'fr',
    mode: 'translation',
    explanation: null,
    confidence: null,
    tokens: <Map<String, dynamic>>[],
  );
  @override
  Future<List<Map<String, dynamic>>> fetchMessageReactions(
    String chatId,
  ) async => [];
  @override
  Stream<MessageReactionChange> watchMessageReactionChanges(String chatId) =>
      const Stream.empty();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('BLA17 native direct composer16710', (tester) async {
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    Future<void> realSettle() async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
      }
    }

    Future<void> capture(String name) async {
      await realSettle();
      debugPrint('BLA17_CAPTURE:' + name);
      await realSettle();
      await realSettle();
    }

    const before = bool.fromEnvironment('BLA17_BEFORE');
    for (final retainedFocus in before ? [false] : [false, true]) {
      final service = _ReviewService(outgoing: true, mode: 'practice');
      final container = _containerForHeader(
        service,
        primaryKnownLanguage: 'en',
        knownLanguages: ['en'],
      );
      await tester.pumpWidget(
        _host(container, theme: blabTheme, locale: const Locale('en')),
      );
      await _settle(tester);
      await realSettle();
      final composer = find.byKey(
        const ValueKey('composer-message-text-field'),
      );
      await tester.tap(composer);
      await realSettle();
      await tester.enterText(composer, 'Keep my draft');
      await realSettle();
      final field = tester.widget<TextField>(composer);
      if (retainedFocus) {
        await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
      } else {
        field.focusNode!.unfocus();
      }
      await realSettle();
      expect(field.focusNode!.hasFocus, retainedFocus);
      final target = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is ChatMessageRow && w.message.id == 'msg-1',
        ),
        matching: find.byType(MessageInteractionTarget),
      );
      await tester.tap(target);
      await realSettle();
      expect(
        find.byKey(const ValueKey('message-action-reply')),
        findsOneWidget,
      );
      final restingY = tester.getTopLeft(composer).dy;
      final label = retainedFocus ? 'retained-focus' : 'unfocused';
      await capture(label + '-before-tap');
      await tester.tap(composer);
      await tester.pump(const Duration(milliseconds: 200));
      debugPrint(
        'COMPOSER16710 tap ' +
            label +
            ' actions=' +
            find
                .byKey(const ValueKey('message-action-reply'))
                .evaluate()
                .length
                .toString(),
      );
      if (!before)
        expect(
          find.byKey(const ValueKey('message-action-reply')),
          findsNothing,
        );
      await capture(label + '-after-tap');
      expect(field.controller!.text, 'Keep my draft');
      expect(field.focusNode!.hasFocus, isTrue);
      final inset = MediaQuery.viewInsetsOf(tester.element(composer)).bottom;
      final raisedY = tester.getTopLeft(composer).dy;
      debugPrint(
        'COMPOSER16710 stable ' +
            label +
            ' inset=' +
            inset.toString() +
            ' y=' +
            raisedY.toString() +
            ' resting=' +
            restingY.toString(),
      );
      expect(inset, greaterThan(100));
      expect(raisedY, lessThan(restingY - 100));
      field.focusNode!.unfocus();
      await realSettle();
      await tester.tap(target);
      await realSettle();
      await tester.tap(find.byKey(const ValueKey('message-action-edit')));
      await realSettle();
      expect(container.read(editingProvider('chat-1'))?.id, 'msg-1');
      expect(field.controller!.text, service.message.originalText);
      expect(
        field.controller!.selection.baseOffset,
        field.controller!.text.length,
      );
      expect(field.focusNode!.hasFocus, isTrue);
      expect(
        MediaQuery.viewInsetsOf(tester.element(composer)).bottom,
        greaterThan(100),
      );
      await capture(label + '-edit');
      await tester.pumpWidget(const SizedBox.shrink());
      await realSettle();
      container.dispose();
    }
    debugPrint('BLA17_CAPTURE:done');
    await realSettle();
  });
}
