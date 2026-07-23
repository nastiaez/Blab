import 'dart:async';

import 'package:blab/app/app_messenger.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/profile/edit_profile_screen.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<void> _pumpEditProfile(
  WidgetTester tester, {
  required UpdateDisplayNameAction action,
  String displayName = 'Alice Local',
}) async {
  final router = GoRouter(
    initialLocation: '/profile/edit',
    routes: [
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (_, _) => const Scaffold(body: Text('profile destination')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith(
          (_) async => UserProfile(displayName: displayName),
        ),
        updateDisplayNameActionProvider.overrideWithValue(action),
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

void main() {
  test('display-name validation trims and rejects launch-invalid values', () {
    expect(validateDisplayName(' Alice '), isNull);
    expect(validateDisplayName('   '), 'Enter your display name');
    expect(
      validateDisplayName('a' * 51),
      'Display name must be 50 characters or fewer',
    );
    expect(
      validateDisplayName('Alice\nAdmin'),
      'Display name contains unsupported characters',
    );
  });

  testWidgets('loads the persisted name with no photo or learning controls', (
    tester,
  ) async {
    await _pumpEditProfile(tester, action: (name) async => name);

    expect(find.text('Alice Local'), findsOneWidget);
    expect(find.textContaining('photo', findRichText: true), findsNothing);
    expect(find.textContaining('Learning'), findsNothing);
    expect(find.textContaining('Tamil'), findsNothing);
  });

  testWidgets('invalid names stay inline and never call the server', (
    tester,
  ) async {
    var calls = 0;
    await _pumpEditProfile(
      tester,
      action: (name) async {
        calls++;
        return name;
      },
    );

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.text('Enter your display name'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'a' * 51);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(
      find.text('Display name must be 50 characters or fewer'),
      findsOneWidget,
    );
    expect(calls, 0);
  });

  testWidgets('successful save trims, navigates, and confirms', (tester) async {
    String? submitted;
    await _pumpEditProfile(
      tester,
      action: (name) async {
        submitted = name;
        return name;
      },
    );

    await tester.enterText(find.byType(TextField), '  Alice Renamed  ');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(submitted, 'Alice Renamed');
    expect(find.text('profile destination'), findsOneWidget);
    expect(find.text('Profile updated ✓'), findsOneWidget);
  });

  testWidgets('pending save blocks duplicates and keeps failures inline', (
    tester,
  ) async {
    final pending = Completer<String>();
    var calls = 0;
    await _pumpEditProfile(
      tester,
      action: (name) {
        calls++;
        return pending.future;
      },
    );

    await tester.enterText(find.byType(TextField), 'Alice Pending');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(calls, 1);
    final back = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.arrow_back_ios_new),
    );
    expect(back.onPressed, isNull);

    pending.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not update your profile. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Alice Pending'), findsOneWidget);
    expect(find.text('Profile updated ✓'), findsNothing);
  });
}
