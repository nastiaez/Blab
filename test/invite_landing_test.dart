import 'package:blab/app/router.dart';
import 'package:blab/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

bool _spanContains(InlineSpan span, String needle) {
  final buf = StringBuffer();
  span.visitChildren((s) {
    if (s is TextSpan && s.text != null) buf.write(s.text);
    return true;
  });
  return buf.toString().contains(needle);
}

/// Helper that boots the full router at a specific deep-link path so we can
/// exercise the query-parameter parsing in `blabRouter`.
Future<void> _bootAt(WidgetTester tester, String location) async {
  // GoRouter is a singleton in the project — push the requested location into
  // it before pumping so the initial route renders the path we want.
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
  testWidgets('/invite default state shows valid invite + Accept & join',
      (tester) async {
    await _bootAt(tester, '/invite?from=Nastia&learn=uk&teach=ta');

    expect(find.text('Accept & join'), findsOneWidget);
    // Heading is a RichText — search the InlineSpan tree for "invited you to
    // learn" (plus "Nastia" and "Ukrainian" appear there as separate spans).
    expect(
      find.byWidgetPredicate((w) =>
          w is RichText && _spanContains(w.text, 'invited you to learn')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
          (w) => w is RichText && _spanContains(w.text, 'Nastia')),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
          (w) => w is RichText && _spanContains(w.text, 'Ukrainian')),
      findsWidgets,
    );
    // Exchange card row label.
    expect(find.text('She teaches you Ukrainian'), findsOneWidget);
  });

  testWidgets('/invite?status=expired shows expired heading + no form',
      (tester) async {
    await _bootAt(tester, '/invite?status=expired&from=Nastia');

    expect(find.text('This invite has expired'), findsOneWidget);
    expect(find.text('Accept & join'), findsNothing);
    expect(find.byIcon(Icons.timer_off_outlined), findsOneWidget);
  });

  testWidgets('/invite?status=used shows used heading + no form',
      (tester) async {
    await _bootAt(tester, '/invite?status=used&from=Nastia');

    expect(find.text('This invite has already been claimed'), findsOneWidget);
    expect(find.text('Accept & join'), findsNothing);
    expect(find.byIcon(Icons.link_off), findsOneWidget);
  });
}
