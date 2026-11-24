import 'package:blab/app/router.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/onboarding/learn_in_context_screen.dart';
import 'package:blab/features/onboarding/learning_language_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/data/local_storage_keys.dart';
import 'package:blab/shared/services/supabase_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NoNetwork implements SupabaseClient {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation i) {
    calls++;
    throw StateError('network disabled');
  }
}

class SignedOut extends SupabaseAuthService {
  SignedOut(super.client);
  @override
  User? get currentUser => null;
  @override
  Session? get currentSession => null;
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
}

void main() {
  testWidgets(
    'production Demo1 Continue→Demo2; Back→Demo1; Skip and current Continue→Learning retain prefs',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        kGuestInterfaceLanguageKey: 'en',
        kGuestInterfaceLanguageExplicitKey: true,
        kPendingInviteTokenKey: 'fixture-invite',
        'fixture_familiar_language': 'en',
        'fixture_learning_language': 'de',
      });
      final prefs = await SharedPreferences.getInstance();
      final before = {for (final k in prefs.getKeys()) k: prefs.get(k)};
      final client = NoNetwork();
      blabRouter.go('/onboarding/learn');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseAuthServiceProvider.overrideWithValue(SignedOut(client)),
          ],
          child: MaterialApp.router(
            theme: blabTheme,
            routerConfig: blabRouter,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        blabRouter.routeInformationProvider.value.uri.path,
        '/onboarding/context',
      );
      expect(
        tester
            .widget<LearnInContextScreen>(find.byType(LearnInContextScreen))
            .demoStep,
        2,
      );
      expect(find.text('Learn words in context'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        blabRouter.routeInformationProvider.value.uri.path,
        '/onboarding/learn',
      );
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        blabRouter.routeInformationProvider.value.uri.path,
        '/onboarding/learning-language',
      );
      expect(find.byType(LearningLanguageScreen), findsOneWidget);
      blabRouter.go('/onboarding/context');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        blabRouter.routeInformationProvider.value.uri.path,
        '/onboarding/grammar',
      );
      expect(find.text('Make sense of grammar'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        blabRouter.routeInformationProvider.value.uri.path,
        '/onboarding/context',
      );
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Continue'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        blabRouter.routeInformationProvider.value.uri.path,
        '/onboarding/learning-language',
      );
      expect({for (final k in prefs.getKeys()) k: prefs.get(k)}, before);
      expect(client.calls, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
