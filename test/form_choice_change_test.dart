import 'package:blab/features/chat/widgets/translating_message_content.dart';
import 'package:blab/features/chat/widgets/grammatical_form_chooser.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:blab/shared/models/grammatical_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a = GrammaticalFormAlternatives(
    before: 'Ти ',
    feminine: 'ходила',
    masculine: 'ходив',
    after: ' вчора?',
    subjectName: 'Alice',
    subjectIsViewer: false,
  );
  testWidgets('selection should show confirmation then Change should reopen', (
    t,
  ) async {
    GrammaticalForm? selected;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (c, setState) => GrammaticalFormChooser(
              alternatives: a,
              selectedForm: selected,
              onChange: () {},
              onSelected: (f) async {
                setState(() => selected = f);
              },
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('ходила'));
    await t.pumpAndSettle();
    expect(
      find.text('Change'),
      findsOneWidget,
      reason: 'a successful selection should become confirmation',
    );
    await t.tap(find.text('Change'));
    await t.pumpAndSettle();
    expect(find.text('ходив'), findsOneWidget);
  });
  testWidgets('externally selected confirmation can reopen', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrammaticalFormChooser(
            alternatives: a,
            selectedForm: GrammaticalForm.feminine,
            onChange: () {},
            onSelected: (f) async {},
          ),
        ),
      ),
    );
    await t.tap(find.text('Change'));
    await t.pumpAndSettle();
    expect(find.text('ходив'), findsOneWidget);
  });
  testWidgets('save failure keeps choices available and shows recovery copy', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrammaticalFormChooser(
            alternatives: a,
            onChange: () {},
            onSelected: (f) async {
              throw StateError('offline');
            },
          ),
        ),
      ),
    );
    await t.tap(find.text('ходила'));
    await t.pumpAndSettle();
    expect(find.text('ходив'), findsOneWidget);
    expect(find.text('Change'), findsNothing);
    expect(find.text('Couldn’t save. Try again.'), findsOneWidget);
  });
  testWidgets('arrival accessibility changes preserve an open Change chooser', (
    t,
  ) async {
    bool reduce = false;
    late StateSetter changeMotion;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              changeMotion = setState;
              return MessageArrival(
                animate: true,
                reduceMotion: reduce,
                outgoing: false,
                child: GrammaticalFormChooser(
                  alternatives: a,
                  selectedForm: GrammaticalForm.feminine,
                  onChange: () {},
                  onSelected: (f) async {},
                ),
              );
            },
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Change'));
    await t.pumpAndSettle();
    expect(find.text('ходив'), findsOneWidget);
    changeMotion(() => reduce = true);
    await t.pumpAndSettle();
    expect(find.text('ходив'), findsOneWidget);
    changeMotion(() => reduce = false);
    await t.pumpAndSettle();
    expect(find.text('ходив'), findsOneWidget);
  });
}
