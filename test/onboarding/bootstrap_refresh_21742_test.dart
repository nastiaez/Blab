import 'dart:async';
import 'package:blab/app/theme.dart';
import 'package:blab/features/onboarding/onboarding_bootstrap_screen.dart';
import 'package:blab/features/onboarding/state/onboarding_destination.dart';
import 'package:blab/features/onboarding/state/onboarding_destination_state.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'post-name bootstrap never delivers cached setup while refreshing',
    (t) async {
      for (final old in [
        OnboardingDestination.confirmName,
        OnboardingDestination.language,
      ]) {
        final pending = Completer<OnboardingDestination>();
        var calls = 0;
        final c = ProviderContainer(
          overrides: [
            openingAnimationGateProvider.overrideWithValue(
              OpeningAnimationGate()..claim(),
            ),
            onboardingDestinationProvider.overrideWith(
              (ref) => ++calls == 1 ? Future.value(old) : pending.future,
            ),
          ],
        );
        final sub = c.listen(onboardingDestinationProvider, (_, _) {});
        await c.read(onboardingDestinationProvider.future);
        c.invalidate(onboardingDestinationProvider);
        final delivered = <OnboardingDestination>[];
        await t.pumpWidget(
          UncontrolledProviderScope(
            container: c,
            child: MaterialApp(
              theme: blabTheme,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: OnboardingBootstrapScreen(onResolved: delivered.add),
            ),
          ),
        );
        await t.pump();
        expect(
          delivered,
          isEmpty,
          reason: 'cached setup must not bounce back after name',
        );
        pending.complete(OnboardingDestination.chats);
        await t.pump();
        await t.pump();
        expect(delivered, [OnboardingDestination.chats]);
        await t.pumpWidget(const SizedBox());
        sub.close();
        c.dispose();
      }
    },
  );
}
