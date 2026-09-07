import 'package:blab/features/chat/widgets/grammatical_form_chooser.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:blab/shared/models/grammatical_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const alternatives = GrammaticalFormAlternatives(
    before: 'Ти ',
    feminine: 'ходила',
    masculine: 'ходив',
    after: ' вчора?',
    subjectName: 'Maya',
    subjectIsViewer: true,
  );

  testWidgets('ambiguous sentence uses one compact ellipsis marker', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrammaticalFormAlternativesText(
            alternatives: alternatives,
            style: const TextStyle(fontSize: 16),
            onMarkerTap: (_) => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('…'), findsOneWidget);
    expect(find.textContaining('/'), findsNothing);
    await tester.tap(find.byType(GrammaticalFormMarker));
    expect(tapped, isTrue);
  });

  testWidgets('chooser uses the revised copy and pill treatment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrammaticalFormChooser(
            alternatives: alternatives,
            showExplanation: true,
            firstTimeExplanation: 'Some languages change words.',
            explanationKey: 'test-language',
            onSelected: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('Some languages change words.'), findsOneWidget);
    expect(find.text('Choose your gendered form'), findsOneWidget);
    expect(find.text('feminine'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.byType(OutlinedButton).first,
    );
    final decoration = button.style?.backgroundColor?.resolve(<WidgetState>{});
    expect(decoration, const Color(0xFFFFFCF8));
    expect(GrammaticalForm.feminine.label, 'Feminine');
  });
}
