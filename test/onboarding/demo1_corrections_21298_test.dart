import 'package:blab/app/router.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/app/onboarding_tokens.dart';
import 'package:blab/features/onboarding/widgets/demo_progress_dots.dart';
import 'package:blab/features/onboarding/learn_in_context_screen.dart';
import 'package:blab/features/onboarding/learning_language_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/data/local_storage_keys.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:blab/shared/services/supabase_auth_service.dart';
import 'learn_in_context_screen_test.dart' as fixture;

class _NoNetworkClient implements SupabaseClient {
  int calls = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls++;
    throw StateError('network disabled');
  }
}

class _SignedOutAuth extends SupabaseAuthService {
  _SignedOutAuth(super.client);
  @override
  User? get currentUser => null;
  @override
  Session? get currentSession => null;
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Roboto')
      ..addFont(rootBundle.load('assets/fonts/deep_dive/Roboto-Variable.ttf'));
    await loader.load();
  });
  testWidgets('actual bubble EDGE gaps are equal after final arrival', (
    tester,
  ) async {
    await tester.pumpWidget(fixture.app(reduced: true));
    await tester.pump();
    final a = tester.getRect(
      find.byKey(const Key('learning-outgoing-message')),
    );
    final b = tester.getRect(
      find.byKey(const Key('learning-incoming-message')),
    );
    final c = tester.getRect(find.byKey(const Key('demo1-sent-translation')));
    expect(b.top - a.bottom, closeTo(OnboardingTheme.demoMessageGap, 0.001));
    expect(c.top - b.bottom, closeTo(b.top - a.bottom, 0.001));
  });
  testWidgets(
    'circle diameter equals field outer height and arrow stays centered through states',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [360.0, 390.0, 430.0]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = Size(width, 844);
          await tester.pumpWidget(fixture.app(scale: scale));
          await tester.pump();
          for (final time in [0, 8500, 2000, 800]) {
            await tester.pump(Duration(milliseconds: time));
            final field = tester.getRect(
              find.byKey(const Key('demo1-composer')),
            );
            final send = tester.getRect(find.byKey(const Key('demo1-send')));
            final arrow = tester.getRect(
              find.byKey(const Key('demo1-send-arrow')),
            );
            expect(send.width, closeTo(send.height, 0.001));
            expect(send.height, closeTo(field.height, 0.001));
            expect(arrow.center.dx, closeTo(send.center.dx, 0.001));
            expect(arrow.center.dy, closeTo(send.center.dy, 0.001));
            expect(tester.takeException(), isNull);
          }
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
  );
  testWidgets(
    'three dots first active, centered against screen despite Back and Skip',
    (tester) async {
      final semantics = tester.ensureSemantics();

      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final width in [360.0, 390.0, 430.0]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = Size(width, 844);
          await tester.pumpWidget(fixture.app(scale: scale));
          expect(find.bySemanticsLabel('Demo 1 of 3'), findsOneWidget);
          expect(find.text('1/3'), findsNothing);
          final dotRects = [
            for (var i = 0; i < 3; i++)
              tester.getRect(find.byKey(ValueKey('demo-progress-dot-$i'))),
          ];
          expect(
            (dotRects.first.left + dotRects.last.right) / 2,
            closeTo(width / 2, 0.001),
          );
          for (var i = 0; i < 3; i++) {
            final d =
                tester
                        .widget<Container>(
                          find.byKey(ValueKey('demo-progress-dot-$i')),
                        )
                        .decoration!
                    as BoxDecoration;
            expect(d.color, i == 0 ? BlabColors.brand : BlabColors.divider);
          }
          expect(find.byType(DemoProgressDots), findsOneWidget);
          expect(find.text('Skip').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      }
      semantics.dispose();
    },
  );
  testWidgets(
    'real production Skip goes to Learning retaining all guest preferences',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        kGuestInterfaceLanguageKey: 'en',
        kGuestInterfaceLanguageExplicitKey: true,
        kPendingInviteTokenKey: 'fixture-invite',
        'fixture_familiar_language': 'de',
        'fixture_learning_language': 'en',
      });
      final prefs = await SharedPreferences.getInstance();
      final before = {for (final key in prefs.getKeys()) key: prefs.get(key)};
      final client = _NoNetworkClient();
      blabRouter.go('/onboarding/learn');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseAuthServiceProvider.overrideWithValue(
              _SignedOutAuth(client),
            ),
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
      expect(find.byType(LearnInContextScreen), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(
        blabRouter.routeInformationProvider.value.uri.path,
        '/onboarding/learning-language',
      );
      expect(find.byType(LearningLanguageScreen), findsOneWidget);
      expect(find.byType(LearnInContextScreen), findsNothing);
      expect(client.calls, 0);
      expect({for (final key in prefs.getKeys()) key: prefs.get(key)}, before);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
