import 'package:blab/app/theme.dart';
import 'package:blab/app/ui_workbench_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('workbench exposes previews, inventory, and comparisons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: blabTheme, home: const UiWorkbenchScreen()),
    );

    expect(find.text('Blab UI workbench'), findsOneWidget);
    expect(find.text('Now learning Spanish'), findsOneWidget);
    expect(find.text('··· Chat menu'), findsOneWidget);

    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();
    expect(find.text('VALUES + SWATCHES'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('Error and retry states'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Normal / Practice mode switch'),
      500,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Normal / Practice mode switch'), findsOneWidget);

    await tester.tap(find.text('Compare'));
    await tester.pumpAndSettle();
    expect(find.text('Consolidation decisions'), findsOneWidget);
    expect(find.text('Recovery intent'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Timeline anchors'),
      400,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Timeline anchors'), findsOneWidget);
  });
}
