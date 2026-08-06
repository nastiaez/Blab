import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _localizedText({Locale? locale}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Builder(builder: (context) => Text(context.l10n.noChatsYet)),
  );
}

void main() {
  testWidgets('English is the app-localization default', (tester) async {
    await tester.pumpWidget(_localizedText());
    expect(find.text('No chats yet'), findsOneWidget);
  });

  testWidgets('German, Spanish, and Ukrainian chrome is generated', (
    tester,
  ) async {
    const expectations = {
      'de': 'Noch keine Chats',
      'es': 'Aún no hay chats',
      'uk': 'Чатів ще немає',
    };

    for (final entry in expectations.entries) {
      await tester.pumpWidget(_localizedText(locale: Locale(entry.key)));
      expect(find.text(entry.value), findsOneWidget);
    }
  });

  test('interface picker exposes only the four launch locales', () {
    expect(kInterfaceLanguages.map((language) => language.code).toSet(), {
      'en',
      'uk',
      'de',
      'es',
    });
  });

  testWidgets('composer uses the generic localized message placeholder', (
    tester,
  ) async {
    const expectations = {
      'en': 'Message',
      'de': 'Nachricht',
      'es': 'Mensaje',
      'uk': 'Повідомлення',
    };

    for (final entry in expectations.entries) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(entry.key),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(builder: (context) => Text(context.l10n.message)),
        ),
      );
      expect(find.text(entry.value), findsOneWidget);
    }
  });

  testWidgets('empty composer uses the localized say-hi placeholder', (
    tester,
  ) async {
    const expectations = {
      'en': 'Say hi',
      'de': 'Sag Hallo',
      'es': 'Saluda',
      'uk': 'Привітайтеся',
    };

    for (final entry in expectations.entries) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(entry.key),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(builder: (context) => Text(context.l10n.sayHi)),
        ),
      );
      expect(find.text(entry.value), findsOneWidget);
    }
  });

  testWidgets('chat learning context is viewer-centered in every locale', (
    tester,
  ) async {
    const expectations = {
      'en': "You're learning English with Alice",
      'de': 'Du lernst English mit Alice',
      'es': 'Estás aprendiendo English con Alice',
      'uk': 'Ви вивчаєте English з Alice',
    };

    for (final entry in expectations.entries) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(entry.key),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Text(
              context.l10n.youAreLearningLanguageWithPerson('English', 'Alice'),
            ),
          ),
        ),
      );
      expect(find.text(entry.value), findsOneWidget);
    }
  });
}
