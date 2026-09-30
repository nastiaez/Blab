import 'package:blab/features/onboarding/widgets/primary_action_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('enabled primary action uses the approved warm shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryActionButton(label: 'Continue', onPressed: () {}),
        ),
      ),
    );

    final shadowBox = tester.widget<DecoratedBox>(
      find.byKey(const Key('primary-action-shadow')),
    );
    final decoration = shadowBox.decoration as BoxDecoration;
    final shadow = decoration.boxShadow!.single;

    expect(shadow.color, const Color(0x24231208));
    expect(shadow.offset, const Offset(0, 8));
    expect(shadow.blurRadius, 22);
  });

  testWidgets('disabled primary action does not cast an active shadow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrimaryActionButton(label: 'Continue', onPressed: null),
        ),
      ),
    );

    final shadowBox = tester.widget<DecoratedBox>(
      find.byKey(const Key('primary-action-shadow')),
    );
    final decoration = shadowBox.decoration as BoxDecoration;

    expect(decoration.boxShadow, isEmpty);
  });

  testWidgets('primary action grows for long labels at 200% text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(370, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: PrimaryActionButton(
              label: 'Створити обліковий запис',
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('primary-action'))).height,
      greaterThan(54),
    );
    expect(tester.takeException(), isNull);
  });
}
