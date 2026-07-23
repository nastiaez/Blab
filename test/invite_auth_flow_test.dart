import 'package:blab/app/theme.dart';
import 'package:blab/features/auth/auth_screen.dart';
import 'package:blab/features/invite/invite_continuation.dart';
import 'package:blab/features/invite/invite_pick_language_screen.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  testWidgets('signed-out picker carries complete invite state into auth', (
    tester,
  ) async {
    late Uri authUri;
    final router = GoRouter(
      initialLocation:
          '/invite/pick-language?inviter=Alice%20%26%20Jorg&token=token-1',
      routes: [
        GoRoute(
          path: '/invite/pick-language',
          builder: (context, state) => InvitePickLanguageScreen(
            inviterName: state.uri.queryParameters['inviter']!,
            token: state.uri.queryParameters['token'],
          ),
        ),
        GoRoute(
          path: '/auth',
          builder: (context, state) {
            authUri = state.uri;
            return const Text('auth destination');
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [isSignedInProvider.overrideWithValue(false)],
        child: MaterialApp.router(theme: blabTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('German'));
    await tester.pump();
    await tester.tap(find.text('Say hallo'));
    await tester.pumpAndSettle();

    expect(find.text('auth destination'), findsOneWidget);
    expect(authUri.queryParameters, {
      'mode': 'signup',
      'invite': 'token-1',
      'inviter': 'Alice & Jorg',
      'learn': 'de',
    });
  });

  testWidgets('email signup claims preserved invite and opens returned chat', (
    tester,
  ) async {
    EmailAuthRequest? request;
    InviteContinuation? claimed;
    final router = _authRouter();
    addTearDown(router.dispose);

    await _pumpRouter(
      tester,
      router,
      emailAuth: (value) async => request = value,
      socialAuth: (_) async {},
      inviteClaim: (value) async {
        claimed = value;
        return 'chat-123';
      },
    );
    await _submitEmailAuth(tester, signUp: true);

    expect(request?.mode, AuthMode.signUp);
    expect(claimed?.token, 'invite-token');
    expect(claimed?.learningLanguage, 'de');
    expect(find.text('chat:chat-123'), findsOneWidget);
  });

  testWidgets('switching to login retains invite and resumes claim', (
    tester,
  ) async {
    EmailAuthRequest? request;
    InviteContinuation? claimed;
    final router = _authRouter();
    addTearDown(router.dispose);

    await _pumpRouter(
      tester,
      router,
      emailAuth: (value) async => request = value,
      socialAuth: (_) async {},
      inviteClaim: (value) async {
        claimed = value;
        return 'chat-login';
      },
    );
    final switchMode = find.text('Already have an account? Log in');
    await tester.ensureVisible(switchMode);
    await tester.pump();
    await tester.tap(switchMode);
    await tester.pumpAndSettle();
    expect(find.text('Log in to chat with Alice.'), findsOneWidget);

    await _submitEmailAuth(tester, signUp: false);

    expect(request?.mode, AuthMode.logIn);
    expect(claimed?.token, 'invite-token');
    expect(claimed?.learningLanguage, 'de');
    expect(find.text('chat:chat-login'), findsOneWidget);
  });

  testWidgets('Google auth resumes the preserved invite', (tester) async {
    var socialCalls = 0;
    var claimCalls = 0;
    final router = _authRouter();
    addTearDown(router.dispose);

    await _pumpRouter(
      tester,
      router,
      emailAuth: (_) async {},
      socialAuth: (provider) async {
        expect(provider, 'google');
        socialCalls++;
      },
      inviteClaim: (continuation) async {
        expect(continuation.token, 'invite-token');
        claimCalls++;
        return 'chat-google';
      },
    );
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(socialCalls, 1);
    expect(claimCalls, 1);
    expect(find.text('chat:chat-google'), findsOneWidget);
  });

  testWidgets('transient claim retry does not repeat successful auth', (
    tester,
  ) async {
    var authCalls = 0;
    var claimCalls = 0;
    final router = _authRouter();
    addTearDown(router.dispose);

    await _pumpRouter(
      tester,
      router,
      emailAuth: (_) async => authCalls++,
      socialAuth: (_) async {},
      inviteClaim: (_) async {
        claimCalls++;
        if (claimCalls == 1) throw Exception('offline');
        return 'chat-retried';
      },
    );

    await _submitEmailAuth(tester, signUp: true);
    expect(find.text("Couldn't accept the invite. Try again."), findsOneWidget);
    expect(authCalls, 1);
    expect(claimCalls, 1);

    await _submitEmailAuth(tester, signUp: true);
    expect(authCalls, 1);
    expect(claimCalls, 2);
    expect(find.text('chat:chat-retried'), findsOneWidget);
  });

  for (final failure in ['invite_expired', 'invite_already_claimed']) {
    testWidgets('$failure returns to authoritative invite resolver', (
      tester,
    ) async {
      final router = _authRouter();
      addTearDown(router.dispose);

      await _pumpRouter(
        tester,
        router,
        emailAuth: (_) async {},
        socialAuth: (_) async {},
        inviteClaim: (_) async => throw PostgrestException(message: failure),
      );
      await _submitEmailAuth(tester, signUp: true);

      expect(find.text('invite:invite-token'), findsOneWidget);
    });
  }

  testWidgets('ordinary auth without invite still opens chats', (tester) async {
    final router = _authRouter();
    router.go('/auth?mode=login');
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
