import 'dart:ui' show CheckedState;

import 'package:blab/app/theme.dart';
import 'package:blab/features/onboarding/confirm_name_screen.dart';
import 'package:blab/features/onboarding/language_you_understand_screen.dart';
import 'package:blab/features/onboarding/state/onboarding_actions.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(
  Widget child, {
  ConfirmOnboardingNameAction? confirmName,
  ConfirmOnboardingLanguageAction? confirmLanguage,
}) {
  return ProviderScope(
    overrides: [
      if (confirmName != null)
        confirmOnboardingNameActionProvider.overrideWithValue(confirmName),
      if (confirmLanguage != null)
        confirmOnboardingLanguageActionProvider.overrideWithValue(
          confirmLanguage,
        ),
    ],
    child: MaterialApp(
      theme: blabTheme,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: child,
    ),
  );
}

void main() {
  test('saved Blab name wins over changed Google metadata', () {
    expect(
      onboardingNameSuggestion(
        savedDisplayName: 'Nastia',
        providerDisplayName: 'New Google Name',
      ),
      'Nastia',
    );
    expect(
      onboardingNameSuggestion(providerDisplayName: 'Google Name'),
      'Google Name',
    );
  });

  test('email signup is blank only before the first name confirmation', () {
    expect(
      onboardingNameSuggestion(
        savedDisplayName: 'Generated email name',
        providerDisplayName: 'Provider name',
        startBlank: true,
      ),
      isEmpty,
    );
    expect(
      onboardingNameSuggestion(savedDisplayName: 'Nastia', startBlank: false),
      'Nastia',
    );
  });

  testWidgets('name confirmation retains and explicitly saves the suggestion', (
    tester,
  ) async {
    String? confirmed;
    await tester.pumpWidget(
      _app(
        ConfirmNameScreen(
          initialName: 'Nastia',
          onBack: () {},
          onComplete: () {},
        ),
        confirmName: (name) async {
          confirmed = name;
        },
      ),
    );

    expect(find.text("What’s your name?"), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Nastia'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(confirmed, 'Nastia');
  });

  testWidgets('name confirmation supports autofill and keyboard submission', (
    tester,
  ) async {
    String? confirmed;
    await tester.pumpWidget(
      _app(
        ConfirmNameScreen(
          initialName: 'Nastia',
          onBack: () {},
          onComplete: () {},
        ),
        confirmName: (name) async => confirmed = name,
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.autofillHints, const [AutofillHints.name]);
    expect(field.textInputAction, TextInputAction.done);

    await tester.tap(find.byType(TextField));
    await tester.enterText(find.byType(TextField), '  Nastia  ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(confirmed, 'Nastia');
  });

  testWidgets('language setup is radio-style and blocks empty submission', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    String? confirmed;
    var backCalls = 0;
    await tester.pumpWidget(
      _app(
        LanguageYouUnderstandScreen(
          onBack: () => backCalls++,
          onComplete: () {},
        ),
        confirmLanguage: (code) async {
          confirmed = code;
        },
      ),
    );

    expect(find.text('Language you understand'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.childrenDelegate.estimatedChildCount, 11);
    expect(find.byType(Radio<String>), findsWidgets);
    final germanSemantics = tester.getSemantics(
      find.bySemanticsLabel('German'),
    );
    expect(germanSemantics.flagsCollection.isChecked, isNot(CheckedState.none));
    expect(germanSemantics.flagsCollection.isInMutuallyExclusiveGroup, isTrue);
    final disabled = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start chatting'),
    );
    expect(disabled.onPressed, isNull);

    await tester.tap(find.byTooltip('Back'));
    expect(backCalls, 1);

    await tester.tap(find.text('German'));
    await tester.pump();
    await tester.tap(find.text('Start chatting'));
    await tester.pumpAndSettle();
    expect(confirmed, 'de');
    semantics.dispose();
  });
}
