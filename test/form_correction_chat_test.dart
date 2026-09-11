import 'package:blab/features/chat/widgets/message_text.dart';
import 'package:blab/features/chat/widgets/grammatical_form_chooser.dart';
import 'package:blab/features/chat/state/grammatical_form_preferences_state.dart';
import 'package:blab/features/chat/state/form_correction_state.dart';
import 'package:blab/features/chat/state/unread_chat_state.dart';
import 'package:blab/shared/services/grammatical_form_preferences_service.dart';
import 'package:blab/shared/models/grammatical_form.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/features/chat/state/typing_state.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:blab/features/chat/translation_preferences_screen.dart';
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
    String text = 'hallo',
    String? translatedText,
    this.sourceLang = 'de',
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
  String mode = 'practice';
  final bool withReaction = false;
  final String _learningText;
  final String sourceLang;
  final String interfaceText = 'hello';
  final bool partnerRead = false;
  final bool translationFails = false;
  final List<String> deletedMessageIds = [];

  @override
  Future<List<Map<String, dynamic>>> fetchChatList() async => [
    {
      'chat_id': 'chat-1',
      'partner_id': 'bob',
      'partner_name': 'Bob',
      'my_learning': 'uk',
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
      tokens: <Map<String, dynamic>>[
        {
          'formAlternatives': {
            'before': 'Ти ',
            'feminine': 'ходила',
            'masculine': 'ходив',
            'after': ' вчора?',
            'subjectName': 'Bob',
            'subjectIsViewer': false,
          },
        },
      ],
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

ProviderContainer _buildContainer(
  ChatService service, {
  TtsService? tts,
  _FormStore? forms,
}) {
  // Default to a recording fake (never a real platform-channel TtsService)
  // so every test in this file stays free of MissingPluginException, even
  // ones that don't care about the speak calls.
  final resolvedTts = tts ?? _RecordingTtsService();
  return ProviderContainer(
    overrides: [
      chatServiceProvider.overrideWithValue(service),
      chatLanguageTimelineProvider('chat-1').overrideWith((ref) async => []),
      grammaticalFormPreferencesServiceProvider.overrideWithValue(
        forms ?? _FormStore(),
      ),
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

Widget _host(ProviderContainer container) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp.router(
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    routerConfig: GoRouter(
      initialLocation: '/chat/chat-1',
      routes: [
        GoRoute(
          path: '/chat/:id',
          builder: (_, state) =>
              ChatScreen(chatId: state.pathParameters['id']!),
        ),
        GoRoute(
          path: '/chat/:id/translation-preferences',
          builder: (_, state) => TranslationPreferencesScreen(
            chatId: state.pathParameters['id']!,
            partnerName: state.uri.queryParameters['name'] ?? 'Bob',
            initialSubjectIsViewer:
                switch (state.uri.queryParameters['subject']) {
                  'viewer' => true,
                  'partner' => false,
                  _ => null,
                },
          ),
        ),
      ],
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _FormStore implements GrammaticalFormPreferencesService {
  GrammaticalForm? partner;
  GrammaticalForm? own;
  final List<GrammaticalForm?> ownWrites = [];
  final List<GrammaticalForm?> partnerWrites = [];
  @override
  Future<void> setOwnForm(GrammaticalForm? form) async {
    ownWrites.add(form);
    own = form;
  }

  @override
  Future<GrammaticalFormPreferences> fetch(String chatId) async =>
      GrammaticalFormPreferences(
        ownForm: own,
        partnerForm: partner,
        tone: ConversationTone.informal,
      );
  @override
  Future<void> setPartnerForm(String chatId, GrammaticalForm? form) async {
    partnerWrites.add(form);
    partner = form;
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

FormResolution _viewerNoteResolution(GrammaticalForm form) => FormResolution(
  chatId: 'chat-1',
  messageId: 'incoming-message',
  targetLang: 'uk',
  sourceText: 'Did you go yesterday?',
  alternatives: const GrammaticalFormAlternatives(
    before: 'Ти ',
    feminine: 'ходила',
    masculine: 'ходив',
    after: ' вчора?',
    subjectName: 'Alice',
    subjectIsViewer: true,
    subjectRole: 'recipient',
    suggestedForm: GrammaticalForm.feminine,
  ),
  form: form,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });
  testWidgets('Copy uses the same masculine sentence as the visible bubble', (
    t,
  ) async {
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    final c = _buildContainer(
      _BubbleExpandChatService(
        text: 'Did you go yesterday?',
        translatedText: 'Ти ходила вчора?',
        sourceLang: 'en',
      ),
    );
    await c
        .read(grammaticalFormPreferencesServiceProvider)
        .setOwnForm(GrammaticalForm.masculine);
    await t.pumpWidget(_host(c));
    await _settle(t);
    await t.longPress(
      find
          .byWidgetPredicate(
            (w) => w is MessageText && w.text == 'Ти ходив вчора?',
          )
          .first,
    );
    await _settle(t);
    await t.tap(find.text('Copy'));
    await _settle(t);
    expect(copied, 'Ти ходив вчора?');
    await t.pumpWidget(const SizedBox.shrink());
    c.dispose();
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
  testWidgets('automatic viewer form uses you and Change opens own picker', (
    t,
  ) async {
    final forms = _FormStore();
    final c = _buildContainer(
      _BubbleExpandChatService(
        text: 'Did you go yesterday?',
        translatedText: 'Ти ходила вчора?',
        sourceLang: 'en',
      ),
      forms: forms,
    );
    await t.pumpWidget(_host(c));
    await _settle(t);
    expect(
      find.byWidgetPredicate(
        (w) => w is MessageText && w.text == 'Ти ходила вчора?',
      ),
      findsWidgets,
    );
    expect(find.text('Using feminine forms for you'), findsOneWidget);
    expect(find.text('Using feminine forms for Alice'), findsNothing);
    expect(find.byType(GrammaticalFormChooser), findsNothing);
    expect(find.byType(GrammaticalFormMarker), findsNothing);
    expect(find.text('#1'), findsNothing);
    await t.tap(find.text('Change'));
    await _settle(t);
    expect(find.text('Translation preferences'), findsOneWidget);
    expect(find.text('Grammatical form'), findsOneWidget);
    expect(find.text('Feminine'), findsOneWidget);
    expect(find.text('Masculine'), findsOneWidget);
    expect(find.text('Not set'), findsWidgets);
    await t.tap(find.text('Masculine'));
    await _settle(t);
    expect(forms.ownWrites, [GrammaticalForm.masculine]);
    expect(forms.partnerWrites, isEmpty);
    await t.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
  testWidgets('provisional automatic note does not save a form preference', (
    t,
  ) async {
    final forms = _FormStore();
    final c = _buildContainer(
      _BubbleExpandChatService(
        text: 'Did you go yesterday?',
        translatedText: 'Ти ходила вчора?',
        sourceLang: 'en',
      ),
      forms: forms,
    );
    await t.pumpWidget(_host(c));
    await _settle(t);

    expect(forms.ownWrites, isEmpty);
    expect(forms.partnerWrites, isEmpty);
    expect(forms.own, isNull);
    expect(forms.partner, isNull);
    expect(find.text('Using feminine forms for you'), findsOneWidget);

    await t.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
  testWidgets('provisional partner note does not save a form preference', (
    t,
  ) async {
    final forms = _FormStore();
    final c = _buildContainer(
      _BubbleExpandChatService(
        isOutgoing: true,
        text: 'Did you go yesterday?',
        translatedText: 'Ти ходила вчора?',
        sourceLang: 'en',
      ),
      forms: forms,
    );
    await t.pumpWidget(_host(c));
    await _settle(t);

    expect(forms.ownWrites, isEmpty);
    expect(forms.partnerWrites, isEmpty);
    expect(forms.own, isNull);
    expect(forms.partner, isNull);
    expect(find.text('Using feminine forms for Bob'), findsOneWidget);

    await t.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
  testWidgets('partner note keeps the name and Change opens partner picker', (
    t,
  ) async {
    final forms = _FormStore();
    final c = _buildContainer(
      _BubbleExpandChatService(
        isOutgoing: true,
        text: 'Did you go yesterday?',
        translatedText: 'Ти ходила вчора?',
        sourceLang: 'en',
      ),
      forms: forms,
    );
    await t.pumpWidget(_host(c));
    await _settle(t);

    expect(find.text('Using feminine forms for Bob'), findsOneWidget);
    await t.tap(find.text('Change'));
    await _settle(t);
    expect(find.text('Translation preferences'), findsOneWidget);
    expect(find.text('Grammatical form'), findsOneWidget);
    await t.tap(find.text('Masculine'));
    await _settle(t);
    expect(forms.ownWrites, isEmpty);
    expect(forms.partnerWrites, [GrammaticalForm.masculine]);

    await t.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
  testWidgets('saved own form wins over automatic feminine fallback', (
    t,
  ) async {
    final c = _buildContainer(
      _BubbleExpandChatService(
        text: 'Did you go yesterday?',
        translatedText: 'Ти ходила вчора?',
        sourceLang: 'en',
      ),
    );
    await c
        .read(grammaticalFormPreferencesServiceProvider)
        .setOwnForm(GrammaticalForm.masculine);
    await t.pumpWidget(_host(c));
    await _settle(t);
    expect(
      find.byWidgetPredicate(
        (w) => w is MessageText && w.text == 'Ти ходив вчора?',
      ),
      findsWidgets,
    );
    expect(find.text('Using masculine forms for you'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
  testWidgets('reopened annotated note follows the current saved form', (
    t,
  ) async {
    String? copied;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    final service = _BubbleExpandChatService(
      text: 'Did you go yesterday?',
      translatedText: 'Ти ходила вчора?',
      sourceLang: 'en',
    );
    final forms = _FormStore()..own = GrammaticalForm.masculine;
    final c = _buildContainer(service, forms: forms);
    await c.read(formCorrectionProvider.future);
    await c
        .read(formCorrectionProvider.notifier)
        .mutate(
          (ledger) => ledger.record(
            _viewerNoteResolution(GrammaticalForm.feminine),
            explicit: false,
            messages: [service.message],
            note: true,
          ),
        );

    await t.pumpWidget(_host(c));
    await _settle(t);

    expect(
      find.byWidgetPredicate(
        (w) => w is MessageText && w.text == 'Ти ходив вчора?',
      ),
      findsWidgets,
    );
    expect(find.text('Using masculine forms for you'), findsOneWidget);
    await t.longPress(
      find
          .byWidgetPredicate(
            (w) => w is MessageText && w.text == 'Ти ходив вчора?',
          )
          .first,
    );
    await _settle(t);
    await t.tap(find.text('Copy'));
    await _settle(t);
    expect(copied, 'Ти ходив вчора?');
    await t.pumpWidget(const SizedBox.shrink());
    c.dispose();
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
  testWidgets(
    'reopened annotated note falls back after preference is cleared',
    (t) async {
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      final service = _BubbleExpandChatService(
        text: 'Did you go yesterday?',
        translatedText: 'Ти ходила вчора?',
        sourceLang: 'en',
      );
      final forms = _FormStore();
      final c = _buildContainer(service, forms: forms);
      await c.read(formCorrectionProvider.future);
      await c
          .read(formCorrectionProvider.notifier)
          .mutate(
            (ledger) => ledger.record(
              _viewerNoteResolution(GrammaticalForm.masculine),
              explicit: false,
              messages: [service.message],
              note: true,
            ),
          );

      await t.pumpWidget(_host(c));
      await _settle(t);

      expect(
        find.byWidgetPredicate(
          (w) => w is MessageText && w.text == 'Ти ходила вчора?',
        ),
        findsWidgets,
      );
      expect(find.text('Using feminine forms for you'), findsOneWidget);
      await t.longPress(
        find
            .byWidgetPredicate(
              (w) => w is MessageText && w.text == 'Ти ходила вчора?',
            )
            .first,
      );
      await _settle(t);
      await t.tap(find.text('Copy'));
      await _settle(t);
      expect(copied, 'Ти ходила вчора?');
      await t.pumpWidget(const SizedBox.shrink());
      c.dispose();
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    },
  );
  testWidgets('annotated message remains correctable after another message', (
    t,
  ) async {
    final forms = _FormStore();
    final c = _buildContainer(
      _BubbleExpandChatService(
        text: 'Did you go yesterday?',
        translatedText: 'Ти ходила вчора?',
        sourceLang: 'en',
      ),
      forms: forms,
    );
    await t.pumpWidget(_host(c));
    await _settle(t);
    await c
        .read(chatMessagesProvider('chat-1').notifier)
        .addOutgoing('Next message');
    await _settle(t);
    await forms.setOwnForm(GrammaticalForm.masculine);
    await c
        .read(formCorrectionProvider.notifier)
        .changePreference(
          subjectIsViewer: true,
          form: GrammaticalForm.masculine,
        );
    c.invalidate(grammaticalFormPreferencesProvider('chat-1'));
    await _settle(t);
    expect(
      find.byWidgetPredicate(
        (w) => w is MessageText && w.text == 'Ти ходив вчора?',
      ),
      findsWidgets,
    );
    expect(find.text('Using masculine forms for you'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
}
