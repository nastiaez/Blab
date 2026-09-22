import 'dart:io';

import 'package:blab/app/theme.dart';
import 'package:blab/shared/widgets/blab_icon.dart';
import 'package:blab/shared/widgets/picker_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('approved palette is the shared app palette', () {
    expect(BlabColors.brand, const Color(0xFFF88C5A));
    expect(BlabColors.brandPress, const Color(0xFFF07D4B));
    expect(BlabColors.appBackground, const Color(0xFFFAF7F2));
    expect(BlabColors.error, const Color(0xFFC62828));
    expect(BlabColors.focusBorder, const Color(0xBFF88C5A));
  });

  test('product UI sources do not reintroduce retired palette colors', () {
    const retiredColors = <String>['d4694a', 'bb573b', 'efebe2'];
    const productPaths = <String>['assets', 'lib', 'tools', 'web'];
    const textExtensions = <String>[
      '.css',
      '.dart',
      '.html',
      '.json',
      '.svg',
      '.xml',
    ];

    final violations = <String>[];
    for (final path in productPaths) {
      final type = FileSystemEntity.typeSync(path);
      final files = type == FileSystemEntityType.directory
          ? Directory(path).listSync(recursive: true).whereType<File>()
          : <File>[File(path)];
      for (final file in files) {
        if (!textExtensions.any(file.path.endsWith)) continue;
        final contents = file.readAsStringSync().toLowerCase();
        for (final color in retiredColors) {
          if (contents.contains(color)) {
            violations.add('${file.path}: #$color');
          }
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('default brand buttons use dark warm ink', () {
    final foreground = blabTheme.filledButtonTheme.style!.foregroundColor!
        .resolve(<WidgetState>{});

    expect(foreground, BlabColors.warmInk);
  });

  testWidgets('BrandButton uses dark ink for its label and progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: blabTheme,
        home: Scaffold(
          body: Column(
            children: [
              BrandButton(label: 'Continue', onPressed: () {}),
              const BrandButton(label: 'Loading', loading: true),
            ],
          ),
        ),
      ),
    );

    expect(
      tester.widget<Text>(find.text('Continue')).style!.color,
      BlabColors.warmInk,
    );
    final progress = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(progress.valueColor!.value, BlabColors.warmInk);
  });

  testWidgets('language cards match the approved flat picker rows', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: blabTheme,
        home: Scaffold(
          body: Column(
            children: [
              LanguageCard(
                key: const Key('selected-language'),
                label: 'English',
                selected: true,
                onTap: () {},
              ),
              LanguageCard(
                key: const Key('unselected-language'),
                label: 'Deutsch',
                selected: false,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );

    final selected = find.byKey(const Key('selected-language'));
    final unselected = find.byKey(const Key('unselected-language'));
    final selectedMaterial = tester.widget<Material>(
      find.descendant(of: selected, matching: find.byType(Material)).first,
    );
    final unselectedMaterial = tester.widget<Material>(
      find.descendant(of: unselected, matching: find.byType(Material)).first,
    );

    expect(tester.getSize(selected).height, 48);
    expect(tester.getSize(unselected).height, 48);
    expect(selectedMaterial.color, const Color(0xFFF7EFE5));
    expect(selectedMaterial.borderRadius, BorderRadius.circular(12));
    expect(unselectedMaterial.color, Colors.transparent);
    expect(
      tester.widget<Text>(find.text('English')).style!.fontWeight,
      FontWeight.w700,
    );
    expect(
      tester.widget<Text>(find.text('Deutsch')).style!.fontWeight,
      FontWeight.w400,
    );
    expect(
      find.descendant(of: selected, matching: find.byType(BlabIcon)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: unselected, matching: find.byType(BlabIcon)),
      findsNothing,
    );
  });
}
