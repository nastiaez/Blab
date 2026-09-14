import 'package:blab/app/theme.dart';
import 'package:blab/features/profile/profile_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/known_languages_state.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/widgets/blab_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpProfile(
  WidgetTester tester, {
  required Locale locale,
  double textScale = 1,
  KnownLanguages knownLanguages = const KnownLanguages(
    codes: ['nl'],
    primary: 'nl',
  ),
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hasPasswordIdentityProvider.overrideWithValue(true),
        authSessionProvider.overrideWith((_) => Stream.value(null)),
        currentProfileProvider.overrideWith(
          (_) async => UserProfile(
            displayName: 'Bob Local',
            interfaceLanguage: locale.languageCode,
          ),
        ),
        knownLanguagesProvider.overrideWith((_) async => knownLanguages),
      ],
      child: MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: blabTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const ProfileScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('German Profile chrome and language names are localized', (
    tester,
  ) async {
    await _pumpProfile(tester, locale: const Locale('de'));

    expect(find.text('KONTO'), findsOneWidget);
    expect(find.text('Übersetzungs\u00adeinstellungen'), findsOneWidget);
    expect(find.text('EINSTELLUNGEN'), findsOneWidget);
    expect(find.text('Niederländisch'), findsOneWidget);
    expect(find.text('Account'), findsNothing);
    expect(find.text('Translation preferences'), findsNothing);
    expect(find.text('Dutch'), findsNothing);
  });

  testWidgets('Profile leading icons grow modestly at 200% text', (
    tester,
  ) async {
    await _pumpProfile(tester, locale: const Locale('de'), textScale: 2);

    final privacyIcon = tester.widget<BlabIcon>(
      find.byWidgetPredicate(
        (widget) => widget is BlabIcon && widget.name == 'historic-shield - 20',
      ),
    );
    expect(privacyIcon.size, 24);
    expect(tester.takeException(), isNull);
  });
}
