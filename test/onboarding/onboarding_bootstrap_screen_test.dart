import 'package:blab/app/theme.dart';
import 'package:blab/features/onboarding/onboarding_bootstrap_screen.dart';
import 'package:blab/features/onboarding/state/onboarding_destination.dart';
import 'package:blab/features/onboarding/state/onboarding_destination_state.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bootstrap uses warm canvas and resolves without wrong screen', (
    tester,
  ) async {
    OnboardingDestination? resolved;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingDestinationProvider.overrideWith(
            (ref) async => OnboardingDestination.confirmName,
          ),
        ],
        child: MaterialApp(
          theme: blabTheme,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: OnboardingBootstrapScreen(
            onResolved: (destination) async => resolved = destination,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('onboarding-bootstrap')), findsOneWidget);
    expect(find.text('Chats'), findsNothing);
    await tester.pump();
    await tester.pump();
    expect(resolved, OnboardingDestination.confirmName);
  });
}
