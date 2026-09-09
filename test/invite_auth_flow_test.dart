import 'package:blab/app/theme.dart';
import 'package:blab/features/auth/auth_screen.dart';
import 'package:blab/features/invite/invite_continuation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

GoRouter _authRouter() {
  return GoRouter(
    initialLocation:
        '/auth?mode=signup&invite=invite-token&inviter=Alice&learn=de',
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) {
          final query = state.uri.queryParameters;
          final continuation = InviteContinuation.fromQuery(query);
          return AuthScreen(
            initialMode: query['mode'] == 'login'
                ? AuthMode.logIn
                : AuthMode.signUp,
            inviteToken: continuation.token,
            inviterName: continuation.inviterName,
            learnCode: continuation.learningLanguage,
          );
        },
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) => Text('chat:${state.pathParameters['id']}'),
      ),
      GoRoute(
        path: '/i/:token',
        builder: (context, state) =>
            Text('invite:${state.pathParameters['token']}'),
      ),
      GoRoute(path: '/chats', builder: (context, state) => const Text('chats')),
      GoRoute(
        path: '/auth/forgot',
        builder: (context, state) => const Text('forgot'),
      ),
      GoRoute(
        path: '/invite',
        builder: (context, state) => const Text('invite landing'),
      ),
    ],
  );
}

Future<void> _pumpRouter(
  WidgetTester tester,
  GoRouter router, {
  required EmailAuthAction emailAuth,
  required SocialAuthAction socialAuth,
  required InviteClaimAction inviteClaim,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        emailAuthActionProvider.overrideWithValue(emailAuth),
        socialAuthActionProvider.overrideWithValue(socialAuth),
        inviteClaimActionProvider.overrideWithValue(inviteClaim),
      ],
      child: MaterialApp.router(theme: blabTheme, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submitEmailAuth(
  WidgetTester tester, {
  required bool signUp,
}) async {
  final fields = find.byType(TextField);
  if (signUp) {
    await tester.enterText(fields.at(0), 'Recipient');
    await tester.enterText(fields.at(1), 'recipient@blab.test');
    await tester.enterText(fields.at(2), 'password123');
    final submit = find.text('Join Blab');
    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.tap(submit);
  } else {
    await tester.enterText(fields.at(0), 'bob@blab.test');
    await tester.enterText(fields.at(1), 'password123');
    final submit = find.text('Log in');
    await tester.ensureVisible(submit);
    await tester.pump();
    await tester.tap(submit);
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final signUp in [true, false]) {
    testWidgets(
      'email auth resumes invite through resolver (signup: $signUp)',
      (tester) async {
        final router = _authRouter();
        addTearDown(router.dispose);
        if (!signUp) router.go('/auth?mode=login&invite=invite-token');
        var authCalls = 0;
        await _pumpRouter(
          tester,
          router,
          emailAuth: (_) async => authCalls++,
          socialAuth: (_) async {},
          inviteClaim: (_) async => throw StateError('resolver owns claim'),
        );
        await _submitEmailAuth(tester, signUp: signUp);
        expect(authCalls, 1);
        expect(find.text('invite:invite-token'), findsOneWidget);
      },
    );
  }

  testWidgets('latest saved valid invite wins over stale auth route', (
    tester,
  ) async {
    await savePendingInvite('most-recent');
    final router = _authRouter();
    addTearDown(router.dispose);
    await _pumpRouter(
      tester,
      router,
      emailAuth: (_) async {},
      socialAuth: (_) async {},
      inviteClaim: (_) async => 'wrong',
    );
    await _submitEmailAuth(tester, signUp: true);
    expect(find.text('invite:most-recent'), findsOneWidget);
    expect(await loadPendingInvite(), 'most-recent');
  });

  testWidgets(
    'restart without invite query restores saved invite after login',
    (tester) async {
      await savePendingInvite('saved-before-restart');
      final router = _authRouter()..go('/auth?mode=login');
      addTearDown(router.dispose);
      await _pumpRouter(
        tester,
        router,
        emailAuth: (_) async {},
        socialAuth: (_) async {},
        inviteClaim: (_) async => 'wrong',
      );
      await _submitEmailAuth(tester, signUp: false);
      expect(find.text('invite:saved-before-restart'), findsOneWidget);
    },
  );

  testWidgets('ordinary auth without invite still opens chats', (tester) async {
    final router = _authRouter()..go('/auth?mode=login');
    addTearDown(router.dispose);
    await _pumpRouter(
      tester,
      router,
      emailAuth: (_) async {},
      socialAuth: (_) async {},
      inviteClaim: (_) async => throw StateError('must not claim'),
    );
    await _submitEmailAuth(tester, signUp: false);
    expect(find.text('chats'), findsOneWidget);
  });
}
