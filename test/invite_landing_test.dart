import 'package:blab/app/router.dart';
import 'package:blab/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _bootAt(WidgetTester tester, String location) async {
  blabRouter.go(location);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        theme: blabTheme,
        routerConfig: blabRouter,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // ── Screen 1: invite landing ──────────────────────────────────────────────

  testWidgets('/invite shows avatar, name, subtitle and CTA',
      (tester) async {
    await _bootAt(tester, '/invite?from=Nastia');

    expect(find.text('Nastia'), findsOneWidget);
    expect(find.text('invited you to chat'), findsOneWidget);
    expect(find.text('Join Nastia'), findsOneWidget);
  });

  testWidgets('/invite?status=expired shows expired heading + no CTA',
      (tester) async {
    await _bootAt(tester, '/invite?status=expired&from=Nastia');

    expect(find.text('This invite expired'), findsOneWidget);
    expect(find.text('Join Nastia'), findsNothing);
    expect(find.byIcon(Icons.timer_off_outlined), findsOneWidget);
  });

  testWidgets('/invite?status=used shows used heading + no CTA',
      (tester) async {
    await _bootAt(tester, '/invite?status=used&from=Nastia');

    expect(find.text('This invite was already claimed'), findsOneWidget);
    expect(find.text('Join Nastia'), findsNothing);
    expect(find.byIcon(Icons.link_off), findsOneWidget);
  });

  // ── Screen 2: language picker ─────────────────────────────────────────────

  testWidgets('/invite/pick-language default state shows disabled Say hello',
      (tester) async {
    await _bootAt(tester, '/invite/pick-language?inviter=Nastia');

    expect(find.text('Pick a language.'), findsOneWidget);
    expect(find.text('Say hello'), findsOneWidget);
    // No language pre-selected — no checkmark visible.
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets(
      '/invite/pick-language tapping a language activates CTA with greeting',
      (tester) async {
    await _bootAt(tester, '/invite/pick-language?inviter=Nastia');

    await tester.tap(find.text('French'));
    await tester.pump();

    expect(find.text('Say bonjour'), findsOneWidget);
  });
}
