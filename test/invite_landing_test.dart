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
  testWidgets('/invite default state shows valid invite + Start chatting',
      (tester) async {
    await _bootAt(tester, '/invite?from=Nastia');

    expect(find.text('Start chatting'), findsOneWidget);
    expect(find.text('Nastia invited you to chat.'), findsOneWidget);
  });

  testWidgets('/invite with learning param shows language-aware headline',
      (tester) async {
    await _bootAt(tester, '/invite?from=Nastia&learning=ta');

    expect(find.text('Nastia invited you to chat.'), findsOneWidget);
    expect(find.text('Start chatting'), findsOneWidget);
  });

  testWidgets('/invite?status=expired shows expired heading + no form',
      (tester) async {
    await _bootAt(tester, '/invite?status=expired&from=Nastia');

    expect(find.text('This invite expired.'), findsOneWidget);
    expect(find.text('Accept & join'), findsNothing);
    expect(find.byIcon(Icons.timer_off_outlined), findsOneWidget);
  });

  testWidgets('/invite?status=used shows used heading + no form',
      (tester) async {
    await _bootAt(tester, '/invite?status=used&from=Nastia');

    expect(find.text('This invite was already claimed.'),
        findsOneWidget);
    expect(find.text('Accept & join'), findsNothing);
    expect(find.byIcon(Icons.link_off), findsOneWidget);
  });
}
