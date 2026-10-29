import 'dart:convert';
import 'package:blab/features/chat/widgets/message_learning_content.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/models/chat.dart';
import 'dart:io';
import 'package:integration_test/integration_test.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:blab/features/chat/widgets/learning_language_sheet.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/translation_preferences_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/models/reading_script.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:blab/shared/state/reading_script_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeChatService implements ChatService {
  _FakeChatService(this.rows);

  final List<Map<String, dynamic>> rows;

  @override
  Future<List<Map<String, dynamic>>> fetchChatList() async => rows;

  @override
  Future<List<String>> fetchPreparationMessageIds(
    String chatId, {
    int limit = 50,
  }) async => [];

  @override
  Stream<List<Map<String, dynamic>>> watchMyMemberships() =>
      const Stream.empty();

  @override
  Stream<void> watchChatListMessageChanges() => const Stream.empty();

  @override
  Stream<void> watchChatListTranslationChanges() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _chatRow(String id, String learningLanguage) => {
  'viewer_id': 'me',
  'chat_id': id,
  'partner_id': 'u2',
  'partner_name': 'Bob',
  'my_learning': learningLanguage,
  'partner_learning': 'en',
  'last_body': '',
  'last_at': '2026-09-14T09:00:00Z',
  'unread_count': 0,
  'my_mode': 'practice',
};

ProviderContainer _preferencesContainer({
  required List<Map<String, dynamic>> rows,
  ReadingScript initial = ReadingScript.native,
  Future<String> Function(String value)? update,
}) => ProviderContainer(
  overrides: [
    currentUserIdProvider.overrideWithValue('alice'),
    authSessionProvider.overrideWith((ref) => const Stream.empty()),
    chatServiceProvider.overrideWithValue(_FakeChatService(rows)),
    currentProfileProvider.overrideWith(
      (ref) async => const UserProfile(displayName: 'Alice'),
    ),
    fetchReadingScriptProvider.overrideWithValue(() async => initial.wire),
    updateReadingScriptProvider.overrideWithValue(
      update ?? (value) async => value,
    ),
  ],
);

Widget _preferencesHost(
  ProviderContainer container, {
  String? chatId,
  Locale locale = const Locale('en'),
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    debugShowCheckedModeBanner: false,
    theme: blabTheme,
    home: TranslationPreferencesScreen(
      chatId: chatId,
      partnerName: chatId == null ? null : 'Bob',
    ),
  ),
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('five languages and Marathi reading-script review', (
    tester,
  ) async {
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    SharedPreferences.setMockInitialValues({});
    final voices = <String, bool>{};
    final tts = TtsService();
    for (final code in ['da', 'fi', 'ko', 'mr', 'pl']) {
      voices[code] = await tts.isLanguageAvailable(code);
      final language = kBlabLanguages.firstWhere((l) => l.code == code);
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: blabTheme,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Language selection preview')),
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    selected = (await showLearningLanguageSheet(
                      context,
                      current: language,
                    ))?.code;
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(language.name),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await binding.takeScreenshot('language-$code');
      await tester.tap(find.text(language.name));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(selected, code);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
    debugPrint('BLA13_VOICES=$voices');
    final container = _preferencesContainer(
      rows: [_chatRow('marathi-chat', 'mr')],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _preferencesHost(container, chatId: 'marathi-chat'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Marathi script'), findsOneWidget);
    await binding.takeScreenshot('marathi-preferences');
    await tester.tap(find.text('Reading script'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('marathi-script-choice');
    await tester.tap(find.text('English letters'));
    await tester.pumpAndSettle();
    expect(find.text('English letters'), findsOneWidget);
    await binding.takeScreenshot('marathi-english-letters');
    for (final sample in _liveSamples) {
      final code = sample['lang'] as String;
      final value = sample['result'] as Map<String, dynamic>;
      final translation = MessageTranslation(
        translation: value['translation'],
        interfaceText: value['interfaceText'],
        interfaceLang: 'en',
        sourceLang: 'en',
        tokens: (value['tokens'] as List)
            .map(
              (t) => MessageToken(
                text: t['text'],
                gloss: t['gloss'],
                romanization: t['roman'],
                isContent: t['isContent'],
              ),
            )
            .toList(),
      );
      for (final script in [
        ReadingScript.native,
        if (code == 'mr') ReadingScript.englishLetters,
      ]) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: blabTheme,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              home: Scaffold(
                appBar: AppBar(
                  title: Text(
                    '${kBlabLanguages.firstWhere((l) => l.code == code).name} · ${script == ReadingScript.native ? 'Native script' : 'English letters'}',
                  ),
                ),
                body: Padding(
                  padding: const EdgeInsets.all(20),
                  child: MessageLearningContent(
                    authoredText: sample['text'],
                    translation: AsyncData(translation),
                    showTranslation: true,
                    learningLanguageCode: code,
                    isOutgoing: false,
                    popupTopInset: 0,
                    unavailableText: 'Unavailable',
                    retryText: 'Retry',
                    mode: ChatMode.practice,
                    knownLanguageCodes: const ['en'],
                    expanded: true,
                    onToggleExpanded: () {},
                    readingScript: script,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await binding.takeScreenshot('text-$code-${script.name}');
      }
    }
  });
}

final _liveSamples =
    jsonDecode(
          r'''[{"lang": "da", "text": "I will bring two books tomorrow, not today.", "tone": "informal", "result": {"mode": "translation", "sourceLang": "en", "translation": "Jeg tager to bøger med i morgen, ikke i dag.", "interfaceText": "I will bring two books tomorrow, not today.", "explanation": null, "confidence": null, "tokens": [{"text": "Jeg", "gloss": "I", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "tager", "gloss": "take/bring", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "to", "gloss": "two", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "bøger", "gloss": "books", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "med", "gloss": "along", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "i", "gloss": "in", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "morgen", "gloss": "tomorrow", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": ",", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "ikke", "gloss": "not", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "i", "gloss": "in", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "dag", "gloss": "day", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": ".", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}], "formAlternatives": null}}, {"lang": "fi", "text": "I will bring two books tomorrow, not today.", "tone": "informal", "result": {"mode": "translation", "sourceLang": "en", "translation": "Tuon kaksi kirjaa huomenna, en tänään.", "interfaceText": "I will bring two books tomorrow, not today.", "explanation": null, "confidence": null, "tokens": [{"text": "Tuon", "gloss": "I bring", "roman": "Tuon", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "kaksi", "gloss": "two", "roman": "kaksi", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "kirjaa", "gloss": "books", "roman": "kirjaa", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "huomenna", "gloss": "tomorrow", "roman": "huomenna", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": ",", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "en", "gloss": "not (I do not)", "roman": "en", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "tänään", "gloss": "today", "roman": "tänään", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": ".", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}], "formAlternatives": null}}, {"lang": "ko", "text": "I will bring two books tomorrow, not today.", "tone": "informal", "result": {"mode": "translation", "sourceLang": "en", "translation": "내일 책 두 권 가져갈게, 오늘은 말고.", "interfaceText": "I will bring two books tomorrow, not today.", "explanation": null, "confidence": null, "tokens": [{"text": "내일", "gloss": "tomorrow", "roman": "naeil", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "책", "gloss": "book", "roman": "chaek", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "두", "gloss": "two", "roman": "du", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "권", "gloss": "counter for books", "roman": "gwon", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "가져갈게", "gloss": "will bring (informal)", "roman": "gajyeogalge", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": ",", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "오늘은", "gloss": "today (topic marker)", "roman": "oneureun", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "말고", "gloss": "not (this)", "roman": "malgo", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": ".", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}], "formAlternatives": null}}, {"lang": "mr", "text": "I will bring two books tomorrow, not today.", "tone": "informal", "result": {"mode": "translation", "sourceLang": "en", "translation": "मी उद्या दोन पुस्तके आणेन, आज नाही.", "interfaceText": "I will bring two books tomorrow, not today.", "explanation": null, "confidence": null, "tokens": [{"text": "मी", "gloss": "I", "roman": "mi", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "उद्या", "gloss": "tomorrow", "roman": "udya", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "दोन", "gloss": "two", "roman": "don", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "पुस्तके", "gloss": "books", "roman": "pustake", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "आणेन", "gloss": "will bring", "roman": "aanen", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": ",", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "आज", "gloss": "today", "roman": "aaj", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "नाही", "gloss": "not", "roman": "nahi", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": ".", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}], "formAlternatives": null}}, {"lang": "pl", "text": "I will bring two books tomorrow, not today.", "tone": "informal", "result": {"mode": "translation", "sourceLang": "en", "translation": "Przyniosę dwie książki jutro, nie dzisiaj.", "interfaceText": "I will bring two books tomorrow, not today.", "explanation": null, "confidence": null, "tokens": [{"text": "Przyniosę", "gloss": "I will bring (future tense verb)", "roman": "pshi-nyo-she", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "dwie", "gloss": "two (feminine numeral)", "roman": "dvye", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "książki", "gloss": "books (plural noun)", "roman": "kshyosh-kee", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "jutro", "gloss": "tomorrow (adverb)", "roman": "yu-tro", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": ",", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "nie", "gloss": "not (negation particle)", "roman": "nye", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "dzisiaj", "gloss": "today (adverb)", "roman": "jee-sha-y", "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": ".", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}], "formAlternatives": null}}]''',
        )
        as List;
