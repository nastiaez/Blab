import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/state/grammatical_form_preferences_state.dart';
import 'package:blab/features/chat/translation_preferences_screen.dart';
import 'package:blab/features/profile/known_languages_screen.dart';
import 'package:blab/features/profile/notification_settings_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/models/grammatical_form.dart';
import 'package:blab/shared/services/grammatical_form_preferences_service.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/services/push_notification_gateway.dart';
import 'package:blab/shared/state/known_languages_state.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:blab/shared/state/push_notifications_state.dart';
import 'package:blab/shared/widgets/blab_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _UnavailablePushGateway implements PushNotificationGateway {
  const _UnavailablePushGateway();

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

Future<void> _pumpLocalized(
  WidgetTester tester, {
  required Locale locale,
  required Widget home,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        knownLanguagesProvider.overrideWith(
          (_) async => const KnownLanguages(codes: ['en'], primary: 'en'),
        ),
        currentProfileProvider.overrideWith(
          (_) async => UserProfile(
            displayName: 'Bob Local',
            interfaceLanguage: locale.languageCode,
          ),
        ),
        grammaticalFormPreferencesProvider.overrideWith(
          (_, _) async => const GrammaticalFormPreferences(
            ownForm: null,
            partnerForm: null,
            tone: ConversationTone.informal,
          ),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: blabTheme,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final languageNames = <String, List<String>>{
    'de': [
      'Niederländisch',
      'Englisch',
      'Französisch',
      'Deutsch',
      'Hindi',
      'Italienisch',
      'Portugiesisch',
      'Spanisch',
      'Tamil',
      'Türkisch',
      'Ukrainisch',
    ],
    'es': [
      'Neerlandés',
      'Inglés',
      'Francés',
      'Alemán',
      'Hindi',
      'Italiano',
      'Portugués',
      'Español',
      'Tamil',
      'Turco',
      'Ucraniano',
    ],
    'uk': [
      'Нідерландська',
      'Англійська',
      'Французька',
      'Німецька',
      'Гінді',
      'Італійська',
      'Португальська',
      'Іспанська',
      'Тамільська',
      'Турецька',
      'Українська',
    ],
  };

  for (final entry in languageNames.entries) {
    testWidgets('Known Languages names follow ${entry.key} interface copy', (
      tester,
    ) async {
      await _pumpLocalized(
        tester,
        locale: Locale(entry.key),
        home: const KnownLanguagesScreen(),
      );

      for (final name in entry.value) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('English'), findsNothing);
    });
  }

  final profileCopy = <String, List<String>>{
    'de': [
      'Übersetzungs\u00adeinstellungen',
      'Deine grammatische Form',
      'Nicht festgelegt',
    ],
    'es': [
      'Preferencias de traducción',
      'Tu forma gramatical',
      'Sin configurar',
    ],
    'uk': ['Налаштування перекладу', 'Твоя граматична форма', 'Не вказано'],
  };

  for (final entry in profileCopy.entries) {
    testWidgets('Translation Preferences follows ${entry.key} interface copy', (
      tester,
    ) async {
      await _pumpLocalized(
        tester,
        locale: Locale(entry.key),
        home: const TranslationPreferencesScreen(),
      );

      for (final text in entry.value) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.text('Translation preferences'), findsNothing);
      expect(find.text('Your gender form'), findsNothing);
      expect(find.text('Not set'), findsNothing);
    });
  }

  for (final entry in <String, List<String>>{
    'de': ['Deine grammatische Form', 'Nicht festgelegt'],
    'uk': ['Твоя граматична форма', 'Не вказано'],
  }.entries) {
    testWidgets(
      'long ${entry.key} preference copy stacks instead of crowding',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pumpLocalized(
          tester,
          locale: Locale(entry.key),
          home: const TranslationPreferencesScreen(),
        );

        final labelRect = tester.getRect(find.text(entry.value.first));
        final valueRect = tester.getRect(find.text(entry.value.last));

        expect(valueRect.top, greaterThanOrEqualTo(labelRect.bottom + 4));
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('Ukrainian preference copy uses informal address', () {
    final localizations = lookupAppLocalizations(const Locale('uk'));

    expect(localizations.yourGrammaticalForm, 'Твоя граматична форма');
    expect(
      localizations.couldNotSavePreference,
      'Не вдалося зберегти. Спробуй ще раз.',
    );
  });

  testWidgets('preference value and chevron form one right-aligned group', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpLocalized(
      tester,
      locale: const Locale('en'),
      home: const TranslationPreferencesScreen(),
    );

    final valueRect = tester.getRect(find.text('Not set'));
    final chevron = find.byWidgetPredicate(
      (widget) => widget is BlabIcon && widget.name == 'nav-arrow-right - 20',
    );
    final chevronRect = tester.getRect(chevron);
    final rowRect = tester.getRect(find.byType(InkWell).first);

    expect(chevronRect.left - valueRect.right, lessThanOrEqualTo(2));
    expect(rowRect.right - chevronRect.right, lessThanOrEqualTo(20));
  });

  testWidgets('unavailable notification settings omit the build warning', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushNotificationGatewayProvider.overrideWithValue(
            const _UnavailablePushGateway(),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: blabTheme,
          home: const NotificationSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("Notifications aren't available in this build"),
      findsNothing,
    );
    expect(find.text('Show message previews'), findsOneWidget);
  });

  test('Ukrainian Privacy and notification copy uses informal address', () {
    final localizations = lookupAppLocalizations(const Locale('uk'));

    expect(
      localizations.typingIndicatorsHelp,
      'Якщо вимкнути, ти не бачитимеш, коли інші друкують, а вони не бачитимуть, коли друкуєш ти.',
    );
    expect(
      localizations.readReceiptsHelp,
      'Якщо вимкнути, ти не бачитимеш сповіщень інших, а вони не бачитимуть твоїх.',
    );
    expect(localizations.privacyPolicyTitle, 'Політика конфіденційності');
    expect(
      localizations.notificationsNotRequested,
      'Відкрий чат, щоб увімкнути сповіщення',
    );
  });

  testWidgets(
    'German form picker localizes its title, choices, and unset value',
    (tester) async {
      await _pumpLocalized(
        tester,
        locale: const Locale('de'),
        home: const TranslationPreferencesScreen(),
      );

      await tester.tap(find.text('Deine grammatische Form'));
      await tester.pumpAndSettle();

      expect(find.text('Grammatische Form'), findsOneWidget);
      expect(find.text('Feminin'), findsOneWidget);
      expect(find.text('Maskulin'), findsOneWidget);
      expect(find.text('Nicht festgelegt'), findsWidgets);
      expect(find.text('Grammatical form'), findsNothing);
      expect(find.text('Feminine'), findsNothing);
      expect(find.text('Masculine'), findsNothing);
      expect(find.text('Not set'), findsNothing);
    },
  );

  testWidgets('German chat preferences localize partner form and tone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpLocalized(
      tester,
      locale: const Locale('de'),
      home: const TranslationPreferencesScreen(
        chatId: 'chat-1',
        partnerName: 'Alexandra Mustermann-Langname',
      ),
    );

    expect(
      find.text('Grammatische Form von Alexandra Mustermann-Langname'),
      findsOneWidget,
    );
    expect(find.text('Gesprächston'), findsOneWidget);
    expect(find.text('Informell'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Gesprächston'));
    await tester.pumpAndSettle();
    expect(find.text('Informell'), findsWidgets);
    expect(find.text('Respektvoll'), findsOneWidget);
    expect(find.text('Conversation tone'), findsNothing);
    expect(find.text('Respectful'), findsNothing);
  });

  testWidgets('failed Spanish tone save shows a localized recovery message', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (_) async => const UserProfile(displayName: 'Bob Local'),
          ),
          grammaticalFormPreferencesProvider.overrideWith(
            (_, _) async => const GrammaticalFormPreferences(
              ownForm: null,
              partnerForm: null,
              tone: ConversationTone.informal,
            ),
          ),
          saveConversationToneProvider.overrideWithValue((_, _) async {
            throw Exception('offline');
          }),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: blabTheme,
          home: const TranslationPreferencesScreen(
            chatId: 'chat-1',
            partnerName: 'Alice Local',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tono de conversación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Respetuoso'));
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo guardar. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('Couldn’t save. Try again.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
