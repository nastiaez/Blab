import 'package:blab/app/router.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/onboarding/state/language_draft.dart';
import 'package:blab/features/onboarding/auth/auth_method_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/services/supabase_auth_service.dart';
import 'package:blab/shared/widgets/actions/blab_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfflineClient implements SupabaseClient {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation i) {
    calls++;
    throw StateError('NO NETWORK');
  }
}

class GuestAuth extends SupabaseAuthService {
  GuestAuth(super.client);
  @override
  User? get currentUser => null;
  @override
  Session? get currentSession => null;
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
}

Future<void> settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(milliseconds: 250));
}

Future<OfflineClient> start(WidgetTester t, String path) async {
  t.view.physicalSize = const Size(390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final client = OfflineClient();
  blabRouter.go(path);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAuthServiceProvider.overrideWithValue(GuestAuth(client)),
      ],
      child: MaterialApp.router(
        theme: blabTheme,
        routerConfig: blabRouter,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await settle(t);
  return client;
}

String get route => blabRouter.routeInformationProvider.value.uri.path;
BlabButton continueButton(WidgetTester t) =>
    t.widget<BlabButton>(find.widgetWithText(BlabButton, 'Continue'));
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'Demo3 → Learning → Understood → Signup, Back retains each independent choice',
    (t) async {
      final c = await start(t, '/onboarding/grammar');
      await t.tap(find.text('Continue'));
      await settle(t);
      expect(route, '/onboarding/learning-language');
      expect(find.text('Language you want to learn'), findsOneWidget);
      expect(continueButton(t).onPressed, isNull);
      expect(find.text('Start chatting'), findsNothing);
      await t.tap(find.text('German'));
      await settle(t);
      expect(continueButton(t).onPressed, isNotNull);
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(route, '/onboarding/grammar');
      await t.tap(find.text('Continue'));
      await settle(t);
      expect(
        t
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'de',
      );
      await t.tap(find.text('Continue'));
      await settle(t);
      expect(route, '/onboarding/understood-language');
      expect(find.text('Language you understand'), findsOneWidget);
      expect(continueButton(t).onPressed, isNull);
      await t.tap(find.text('English'));
      await settle(t);
      await t.tap(find.byTooltip('Back'));
      await settle(t);
      expect(
        t
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'de',
      );
      await t.tap(find.text('Continue'));
      await settle(t);
      expect(
        t
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'en',
      );
      await t.tap(find.text('Continue'));
      await settle(t);
      expect(route, '/auth/signup');
      expect(find.byType(AuthMethodScreen), findsOneWidget);
      await t.binding.handlePopRoute();
      await settle(t);
      expect(route, '/onboarding/understood-language');
      expect(
        t
            .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
            .groupValue,
        'en',
      );
      final draft = await LanguageDraftStore().guest();
      expect(draft.learning, 'de');
      expect(draft.understood, 'en');
      expect(c.calls, 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump();
    },
  );
  testWidgets('Skip bypasses only demos and never language selection', (
    t,
  ) async {
    final c = await start(t, '/onboarding/learn');
    for (final path in [
      '/onboarding/learn',
      '/onboarding/context',
      '/onboarding/grammar',
    ]) {
      blabRouter.go(path);
      await settle(t);
      await t.tap(find.text('Skip'));
      await settle(t);
      expect(route, '/onboarding/learning-language');
    }
    expect((await LanguageDraftStore().guest()).complete, isFalse);
    expect(c.calls, 0);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump();
  });
  testWidgets(
    'signup deep entry cannot bypass either mandatory language; legacy login remains available',
    (t) async {
      final c = await start(t, '/auth/signup');
      await settle(t);
      expect(route, '/onboarding/learning-language');
      expect(continueButton(t).onPressed, isNull);
      await t.tap(find.text('German'));
      await settle(t);
      blabRouter.go('/auth/signup/email');
      await settle(t);
      await settle(t);
      expect(route, '/onboarding/understood-language');
      expect(continueButton(t).onPressed, isNull);
      blabRouter.go('/auth/login');
      await settle(t);
      expect(route, '/auth/login');
      expect(c.calls, 0);
      await t.pumpWidget(const SizedBox());
      await t.pump();
    },
  );
}
