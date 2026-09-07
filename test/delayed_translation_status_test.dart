import 'package:blab/features/chat/widgets/delayed_translation_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(bool active) => MaterialApp(
  home: DelayedTranslationStatus(
    active: active,
    status: const Text('Translating…'),
    idle: const Text('Idle'),
  ),
);

void main() {
  testWidgets('status replaces idle content only after 350 milliseconds', (
    tester,
  ) async {
    await tester.pumpWidget(_host(true));
    expect(find.text('Idle'), findsOneWidget);
    expect(find.text('Translating…'), findsNothing);

    await tester.pump(const Duration(milliseconds: 349));
    expect(find.text('Idle'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Translating…'), findsOneWidget);

    await tester.pumpWidget(_host(false));
    await tester.pump();
    expect(find.text('Idle'), findsOneWidget);
    expect(find.text('Translating…'), findsNothing);
  });
}
