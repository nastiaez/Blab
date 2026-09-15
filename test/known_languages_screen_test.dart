import 'package:blab/app/app_messenger.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/profile/known_languages_screen.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/state/profile_state.dart';
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
  testWidgets('toggling a language card selects it', (tester) async {
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

    // English starts selected (seeded from the provider).
    expect(
      tester
          .widgetList<Semantics>(
            find.ancestor(
              of: find.text('English'),
              matching: find.byType(Semantics),
            ),
          )
          .first
          .properties
          .selected,
      isTrue,
    );

    // Ukrainian starts unselected.
    final ukrainianSemantics = find
        .ancestor(of: find.text('Ukrainian'), matching: find.byType(Semantics))
        .first;
    expect(
      tester.widget<Semantics>(ukrainianSemantics).properties.selected,
      isFalse,
    );

    await tester.ensureVisible(find.text('Ukrainian'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ukrainian'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Semantics>(ukrainianSemantics).properties.selected,
      isTrue,
    );
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
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(service.savedCodes, containsAll(['en', 'uk']));
    expect(service.savedPrimary, 'en');
    expect(find.text('profile destination'), findsOneWidget);
    expect(find.text('Profile updated ✓'), findsNothing);
  });

  testWidgets('failed apply stays on Known Languages with error feedback', (
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
    await tester.tap(find.text('Apply'));
    await tester.pump();

    expect(find.text('Known languages'), findsOneWidget);
    expect(
      find.text('Could not update your profile. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Profile updated ✓'), findsNothing);
  });
}
