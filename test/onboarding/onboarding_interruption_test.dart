import 'package:blab/app/theme.dart';
import 'package:blab/features/onboarding/confirm_name_screen.dart';
import 'package:blab/features/onboarding/language_you_understand_screen.dart';
import 'package:blab/features/onboarding/state/onboarding_actions.dart';
import 'package:blab/features/onboarding/state/onboarding_destination.dart';
import 'package:blab/features/onboarding/state/onboarding_resolver.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/data/local_storage_keys.dart';
import 'package:blab/shared/models/onboarding_stage.dart';
import 'package:blab/shared/services/supabase_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

OnboardingDestination _restartDestination(OnboardingStage stage) =>
    resolveOnboardingDestination(
      OnboardingResolverInput(
        bootstrapReady: true,
        signedIn: true,
        profileState: ProfileResolutionState.ready,
        account: AccountOnboardingState(
          version: currentOnboardingVersion,
          stage: stage,
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('process restart resumes the first unfinished server stage', () {
    expect(
      _restartDestination(OnboardingStage.intro),
      OnboardingDestination.welcome,
    );
    expect(
      _restartDestination(OnboardingStage.name),
      OnboardingDestination.confirmName,
    );
    expect(
      _restartDestination(OnboardingStage.language),
      OnboardingDestination.language,
    );
    expect(
      _restartDestination(OnboardingStage.complete),
      OnboardingDestination.chats,
    );
  });

  testWidgets('failed name write stays on the same step and can retry', (
    tester,
  ) async {
    var attempts = 0;
    var completions = 0;
    await tester.pumpWidget(
      _app(
        ConfirmNameScreen(
          initialName: 'Nastia',
          onBack: () {},
          onComplete: () => completions++,
        ),
        confirmName: (_) async {
          attempts++;
          if (attempts == 1) throw StateError('offline');
        },
      ),
    );

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not update your profile. Try again.'),
      findsOneWidget,
    );
    expect(completions, 0);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(completions, 1);
  });

  testWidgets('failed language write stays selected and can retry', (
    tester,
  ) async {
    var attempts = 0;
    var completions = 0;
    await tester.pumpWidget(
      _app(
        LanguageYouUnderstandScreen(
          onBack: () {},
          onComplete: () => completions++,
        ),
        confirmLanguage: (_) async {
          attempts++;
          if (attempts == 1) throw StateError('offline');
        },
      ),
    );

    await tester.tap(find.text('German'));
    await tester.pump();
    await tester.tap(find.text('Start chatting'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't save language. Try again."), findsOneWidget);
    expect(completions, 0);

    await tester.tap(find.text('Start chatting'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(completions, 1);
  });

  test(
    'reinstall clears local attempt state but server progress still resumes',
    () async {
      SharedPreferences.setMockInitialValues({
        kGuestInterfaceLanguageKey: 'de',
        kGuestInterfaceLanguageExplicitKey: true,
        kPendingInterfaceLanguageSyncKey: 'de',
        kPendingInterfaceLanguageSyncUserIdKey: 'account-a',
      });
      final preferences = await SharedPreferences.getInstance();

      await preferences.clear();

      expect(preferences.getKeys(), isEmpty);
      expect(
        _restartDestination(OnboardingStage.name),
        OnboardingDestination.confirmName,
      );
    },
  );

  test(
    'offline bootstrap retries and a revoked session returns to Welcome',
    () {
      expect(
        resolveOnboardingDestination(
          const OnboardingResolverInput(
            bootstrapReady: true,
            signedIn: true,
            profileState: ProfileResolutionState.retry,
          ),
        ),
        OnboardingDestination.retry,
      );
      expect(
        SupabaseAuthService.isRevokedSessionError(
          const AuthException('Invalid Refresh Token: Refresh Token Not Found'),
        ),
        isTrue,
      );
      expect(sessionLossBootstrapLocation, '/bootstrap');
      expect(
        resolveOnboardingDestination(
          const OnboardingResolverInput(bootstrapReady: true),
        ),
        OnboardingDestination.welcome,
      );
    },
  );
}
