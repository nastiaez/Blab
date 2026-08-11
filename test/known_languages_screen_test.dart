import 'package:blab/features/profile/known_languages_screen.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
