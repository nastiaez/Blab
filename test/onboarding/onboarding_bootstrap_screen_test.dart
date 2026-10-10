import 'package:blab/app/theme.dart';
import 'package:blab/features/onboarding/onboarding_bootstrap_screen.dart';
import 'package:blab/features/onboarding/state/onboarding_destination.dart';
import 'package:blab/features/onboarding/state/onboarding_destination_state.dart';
import 'package:blab/features/onboarding/widgets/blab_wordmark_animation.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bootstrap finishes the wordmark before resolving', (
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
    expect(resolved, isNull);

    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(BlabWordmarkAnimation.duration);
    await tester.pump();
    expect(resolved, OnboardingDestination.confirmName);
  });

  testWidgets('reduced motion shows the final wordmark and resolves directly', (
    tester,
  ) async {
    OnboardingDestination? resolved;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingDestinationProvider.overrideWith(
            (ref) async => OnboardingDestination.chats,
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            theme: blabTheme,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: OnboardingBootstrapScreen(
              onResolved: (destination) async => resolved = destination,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('blab-first-b')), findsOneWidget);
    expect(find.byKey(const Key('blab-l')), findsOneWidget);
    expect(find.byKey(const Key('blab-a')), findsOneWidget);
    expect(find.byKey(const Key('blab-last-b')), findsOneWidget);
    expect(resolved, OnboardingDestination.chats);
  });
}
