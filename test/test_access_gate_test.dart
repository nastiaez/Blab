import 'package:blab/features/invite/test_access_gate.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
