import 'dart:async';

import 'package:blab/app/app_messenger.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/profile/change_password_screen.dart';
import 'package:blab/features/profile/profile_screen.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

GoRouter _router() => GoRouter(
  initialLocation: '/profile/password',
  routes: [
    GoRoute(
      path: '/profile/password',
          builder: (_, _) => const ChangePasswordScreen(),
    ),
    GoRoute(
      path: '/profile',
          builder: (_, _) => const Scaffold(body: Text('profile destination')),
    ),
    GoRoute(
      path: '/auth/forgot',
          builder: (_, _) => const Scaffold(body: Text('forgot destination')),
    ),
  ],
);

Future<void> _pumpChangePassword(
  WidgetTester tester, {
  required ChangePasswordAction action,
  bool hasPasswordIdentity = true,
}) async {
  final router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        hasPasswordIdentityProvider.overrideWithValue(hasPasswordIdentity),
        changePasswordActionProvider.overrideWithValue(action),
      ],
      child: MaterialApp.router(
        theme: blabTheme,
        scaffoldMessengerKey: appMessengerKey,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterValidPasswords(WidgetTester tester) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(0), 'OldPass123!');
  await tester.enterText(fields.at(1), 'NewPass456!');
  await tester.enterText(fields.at(2), 'NewPass456!');
}

void main() {
  testWidgets('invalid or unchanged input never invokes Auth', (tester) async {
    var calls = 0;
    await _pumpChangePassword(
      tester,
      action: ({required currentPassword, required newPassword}) async {
        calls++;
      },
    );

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter your current password'), findsOneWidget);
    expect(find.text('Enter a new password'), findsOneWidget);
    expect(find.text('Confirm your new password'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'SamePass123!');
    await tester.enterText(fields.at(1), 'SamePass123!');
    await tester.enterText(fields.at(2), 'SamePass123!');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.text('Choose a different password'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('successful server update is the only success path', (
    tester,
  ) async {
    String? current;
    String? next;
    await _pumpChangePassword(
      tester,
      action: ({required currentPassword, required newPassword}) async {
        current = currentPassword;
        next = newPassword;
      },
    );
    await _enterValidPasswords(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(current, 'OldPass123!');
    expect(next, 'NewPass456!');
    expect(find.text('profile destination'), findsOneWidget);
    expect(find.text('Password updated ✓'), findsOneWidget);
  });

  testWidgets('wrong current password remains inline without success', (
    tester,
  ) async {
    await _pumpChangePassword(
      tester,
      action: ({required currentPassword, required newPassword}) async {
        throw const AuthException('Invalid login credentials');
      },
    );
    await _enterValidPasswords(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Current password is incorrect'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Password updated ✓'), findsNothing);
  });

  testWidgets('busy state blocks duplicate submission and back navigation', (
    tester,
  ) async {
    final pending = Completer<void>();
    var calls = 0;
    await _pumpChangePassword(
      tester,
      action: ({required currentPassword, required newPassword}) {
        calls++;
        return pending.future;
      },
    );
    await _enterValidPasswords(tester);

    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final back = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_back_ios_new),
    );
    expect(back.onPressed, isNull);

    pending.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not update your password. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Password updated ✓'), findsNothing);
  });

  testWidgets('Google-only direct route has no password form', (tester) async {
    await _pumpChangePassword(
      tester,
      hasPasswordIdentity: false,
      action: ({required currentPassword, required newPassword}) async {},
    );

    expect(
      find.text('Password sign-in is not enabled for this account.'),
      findsOneWidget,
    );
    expect(find.text('Save'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('Google-only profile hides Change password', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          hasPasswordIdentityProvider.overrideWithValue(false),
          authSessionProvider.overrideWith((_) => Stream.value(null)),
        ],
        child: MaterialApp(theme: blabTheme, home: const ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Change password'), findsNothing);
    expect(find.text('Change email'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget);
  });
}
