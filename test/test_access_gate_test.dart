import 'dart:async';
import 'package:blab/features/invite/test_access_gate.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('connecting has no logout; denied access retains recovery', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('alice'),
          testAccessCheckProvider.overrideWithValue(() => pending.future),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TestAccessGate(
            child: Column(
              children: [OfflineBanner(), Text('Private chat content')],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Connecting…'), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
    expect(find.text('Private chat content'), findsOneWidget);
    pending.complete({'channel': 'test', 'status': 'not_approved'});
    await tester.pumpAndSettle();
    expect(find.text('Testing access required'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('native account picker resume preserves in-flight sign-in', (
    tester,
  ) async {
    var status = 'signed_out';
    Completer<Map<String, dynamic>>? pending;
    final key = GlobalKey<_SignInProbeState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue(null),
          testAccessCheckProvider.overrideWithValue(
            () async => pending == null
                ? {'channel': 'test', 'status': status}
                : pending.future,
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TestAccessGate(child: _SignInProbe(key: key)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = key.currentState!;
    pending = Completer<Map<String, dynamic>>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(
      before.mounted,
      isTrue,
      reason: 'Access refresh must not dispose the Google callback owner',
    );
    expect(find.text('Auth screen'), findsOneWidget);
    pending.complete({'channel': 'test', 'status': status});
    await tester.pumpAndSettle();
    expect(identical(key.currentState, before), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'server revocation and network failure hide an already-open test app',
    (tester) async {
      var status = 'active';
      var fail = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('alice'),
            testAccessCheckProvider.overrideWithValue(() async {
              if (fail) throw Exception('offline');
              return {'channel': 'test', 'status': status};
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const TestAccessGate(child: Text('Private chat content')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private chat content'), findsOneWidget);
      status = 'ended';
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('Private chat content'), findsNothing);
      expect(find.text('This testing session has ended'), findsOneWidget);
      status = 'active';
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Private chat content'), findsOneWidget);
      fail = true;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('Private chat content'), findsNothing);
      expect(find.text('Couldn’t check test access'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('public backend cannot unlock the test app', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('alice'),
          testAccessCheckProvider.overrideWithValue(
            () async => {'channel': 'public', 'status': 'active'},
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const TestAccessGate(child: Text('Private chat content')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Private chat content'), findsNothing);
    expect(find.text('Couldn’t check test access'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final locale in ['en', 'de', 'es', 'uk']) {
    testWidgets('test gate fits large text in $locale', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('alice'),
            testAccessCheckProvider.overrideWithValue(
              () async => {'channel': 'test', 'status': 'not_approved'},
            ),
          ],
          child: MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const TestAccessGate(child: Text('Private chat content')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Private chat content'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

class _SignInProbe extends StatefulWidget {
  const _SignInProbe({super.key});
  @override
  State<_SignInProbe> createState() => _SignInProbeState();
}

class _SignInProbeState extends State<_SignInProbe> {
  @override
  Widget build(BuildContext context) => const Text('Auth screen');
}
