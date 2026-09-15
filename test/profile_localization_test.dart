import 'dart:async';

import 'package:blab/app/theme.dart';
import 'package:blab/features/profile/profile_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/services/push_notification_gateway.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/known_languages_state.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:blab/shared/state/push_notifications_state.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/widgets/blab_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PushGateway implements PushNotificationGateway {
  const _PushGateway({required this.isSupported});

  @override
  final bool isSupported;

  @override
  Future<PushAuthorizationStatus> authorizationStatus() async => isSupported
      ? PushAuthorizationStatus.denied
      : PushAuthorizationStatus.unavailable;

  @override
  Future<PushAuthorizationStatus> requestPermission() async =>
      PushAuthorizationStatus.denied;

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

Future<void> _pumpProfile(
  WidgetTester tester, {
  required Locale locale,
  double textScale = 1,
  bool pushSupported = false,
  KnownLanguages knownLanguages = const KnownLanguages(
    codes: ['nl'],
    primary: 'nl',
  ),
}) async {
  SharedPreferences.setMockInitialValues({});
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
        pushNotificationGatewayProvider.overrideWithValue(
          _PushGateway(isSupported: pushSupported),
        ),
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

  test('Known Languages headings use direct personal copy', () {
    expect(
      lookupAppLocalizations(const Locale('en')).knownLanguages,
      'Languages you know',
    );
    expect(
      lookupAppLocalizations(const Locale('de')).knownLanguages,
      'Sprachen, die du sprichst',
    );
    expect(
      lookupAppLocalizations(const Locale('es')).knownLanguages,
      'Idiomas que hablas',
    );
    expect(
      lookupAppLocalizations(const Locale('uk')).knownLanguages,
      'Мови, які ти знаєш',
    );
  });

  test('Ukrainian profile error uses informal copy', () {
    final localizations = lookupAppLocalizations(const Locale('uk'));

    expect(
      localizations.couldNotUpdateProfile,
      'Не вдалося оновити профіль. Спробуй ще раз.',
    );
  });

  testWidgets('Profile hides Notifications when push is unavailable', (
    tester,
  ) async {
    await _pumpProfile(tester, locale: const Locale('en'));

    expect(find.text('Privacy'), findsOneWidget);
    expect(find.text('Notifications'), findsNothing);
  });

  testWidgets('Profile shows Notifications when push is supported', (
    tester,
  ) async {
    await _pumpProfile(tester, locale: const Locale('en'), pushSupported: true);

    expect(find.text('Notifications'), findsOneWidget);
  });
}
