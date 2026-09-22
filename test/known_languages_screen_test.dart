import 'package:blab/app/app_messenger.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/profile/known_languages_screen.dart';
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

void main() {
  testWidgets('shows the approved understood-language copy and selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (_) async => const UserProfile(
              displayName: 'Alice',
              interfaceLanguage: 'en',
              knownLanguages: ['en'],
              primaryKnownLanguage: 'en',
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: KnownLanguagesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Languages you understand'), findsOneWidget);
    expect(
      find.text(
        'Select every language you can read without translation. '
        'In Normal mode, messages in these languages stay as written.',
      ),
      findsOneWidget,
    );

    // English starts selected (seeded from the provider).
    final initialEnglishCard = find
        .ancestor(of: find.text('English'), matching: find.byType(LanguageCard))
        .first;
    expect(tester.widget<LanguageCard>(initialEnglishCard).selected, isTrue);

    // Ukrainian starts unselected.
    final initialUkrainianCard = find
        .ancestor(
          of: find.text('Ukrainian'),
          matching: find.byType(LanguageCard),
        )
        .first;
    expect(tester.widget<LanguageCard>(initialUkrainianCard).selected, isFalse);

    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.byIcon(Icons.star_border_rounded), findsNothing);

    await tester.ensureVisible(find.text('Ukrainian'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ukrainian'));
    await tester.pumpAndSettle();

    final ukrainianCard = find
        .ancestor(
          of: find.text('Ukrainian'),
          matching: find.byType(LanguageCard),
        )
        .first;
    expect(tester.widget<LanguageCard>(ukrainianCard).selected, isTrue);
  });

  testWidgets('Save is inactive until the understood languages change', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (_) async => const UserProfile(
              displayName: 'Alice',
              interfaceLanguage: 'en',
              knownLanguages: ['en'],
              primaryKnownLanguage: 'en',
            ),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: KnownLanguagesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final save = tester.widget<BrandButton>(
      find.widgetWithText(BrandButton, 'Save'),
    );
    expect(save.onPressed, isNull);
  });

  testWidgets('successful apply returns without redundant feedback', (
    tester,
  ) async {
    final service = _RecordingProfileService();
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, _) => const Scaffold(body: Text('profile destination')),
        ),
        GoRoute(
          path: '/profile/languages',
          builder: (_, _) => const KnownLanguagesScreen(),
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
              knownLanguages: ['en'],
              primaryKnownLanguage: 'en',
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
    router.push('/profile/languages');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ukrainian'));
    await tester.tap(find.text('Ukrainian'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(service.savedCodes, containsAll(['en', 'uk']));
    expect(service.savedPrimary, 'en');
    expect(find.text('profile destination'), findsOneWidget);
    expect(find.text('Profile updated ✓'), findsNothing);
  });

  testWidgets(
    'removing the translation language assigns the first remaining language',
    (tester) async {
      final service = _RecordingProfileService();
      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (_, _) =>
                const Scaffold(body: Text('profile destination')),
          ),
          GoRoute(
            path: '/profile/languages',
            builder: (_, _) => const KnownLanguagesScreen(),
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
                knownLanguages: ['en', 'uk'],
                primaryKnownLanguage: 'en',
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
      router.push('/profile/languages');
      await tester.pumpAndSettle();

      await tester.tap(find.text('English'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(service.savedCodes, ['uk']);
      expect(service.savedPrimary, 'uk');
    },
  );

  testWidgets('failed save stays on understood languages with error feedback', (
    tester,
  ) async {
    final service = _RecordingProfileService(failure: Exception('offline'));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (_) async => const UserProfile(
              displayName: 'Alice',
              interfaceLanguage: 'en',
              knownLanguages: ['en'],
              primaryKnownLanguage: 'en',
            ),
          ),
          profileServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: blabTheme,
          scaffoldMessengerKey: appMessengerKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const KnownLanguagesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Ukrainian'));
    await tester.tap(find.text('Ukrainian'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Languages you understand'), findsOneWidget);
    expect(
      find.text('Could not update your profile. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Profile updated ✓'), findsNothing);
  });
}
