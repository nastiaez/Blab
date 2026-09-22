import 'package:blab/app/app_messenger.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/profile/translation_language_screen.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:blab/shared/widgets/picker_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _RecordingProfileService implements ProfileService {
  _RecordingProfileService({this.failure});

  final Object? failure;
  List<String>? savedCodes;
  String? savedPrimary;

  @override
  Future<void> setKnownLanguages({
    required List<String> languageCodes,
    required String primaryCode,
  }) async {
    if (failure != null) throw failure!;
    savedCodes = languageCodes;
    savedPrimary = primaryCode;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<GoRouter> _pumpScreen(
  WidgetTester tester, {
  required _RecordingProfileService service,
}) async {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('profile destination')),
      ),
      GoRoute(
        path: '/profile/translation-language',
        builder: (_, _) => const TranslationLanguageScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith(
          (_) async => const UserProfile(
            displayName: 'Alice',
            interfaceLanguage: 'en',
            knownLanguages: ['es'],
            primaryKnownLanguage: 'es',
          ),
        ),
        profileServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp.router(
        theme: blabTheme,
        scaffoldMessengerKey: appMessengerKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  router.push('/profile/translation-language');
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('shows the approved copy and current translation language', (
    tester,
  ) async {
    await _pumpScreen(tester, service: _RecordingProfileService());

    expect(find.text('Translation language'), findsOneWidget);
    expect(
      find.text(
        'Choose the language you understand best. '
        'Blab uses it for translations and explanations.',
      ),
      findsOneWidget,
    );

    final spanishCard = find
        .ancestor(of: find.text('Spanish'), matching: find.byType(LanguageCard))
        .first;
    expect(tester.widget<LanguageCard>(spanishCard).selected, isTrue);
    expect(find.text('Ukrainian'), findsOneWidget);

    final save = tester.widget<BrandButton>(
      find.widgetWithText(BrandButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets(
    'choosing a new translation language also adds it to understood languages',
    (tester) async {
      final service = _RecordingProfileService();
      await _pumpScreen(tester, service: service);

      await tester.ensureVisible(find.text('Ukrainian'));
      await tester.tap(find.text('Ukrainian'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(service.savedCodes, ['es', 'uk']);
      expect(service.savedPrimary, 'uk');
      expect(find.text('profile destination'), findsOneWidget);
    },
  );

  testWidgets('Back discards the draft translation language', (tester) async {
    final service = _RecordingProfileService();
    await _pumpScreen(tester, service: service);

    await tester.ensureVisible(find.text('Ukrainian'));
    await tester.tap(find.text('Ukrainian'));
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(service.savedCodes, isNull);
    expect(service.savedPrimary, isNull);
    expect(find.text('profile destination'), findsOneWidget);
  });

  testWidgets('failed save stays on the picker with recovery feedback', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      service: _RecordingProfileService(failure: Exception('offline')),
    );

    await tester.ensureVisible(find.text('Ukrainian'));
    await tester.tap(find.text('Ukrainian'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Translation language'), findsOneWidget);
    expect(
      find.text('Could not update your profile. Try again.'),
      findsOneWidget,
    );
  });
}
