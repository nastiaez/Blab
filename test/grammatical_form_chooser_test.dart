import 'package:blab/l10n/l10n.dart';
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
  for (final locale in ['en', 'de', 'es', 'uk']) {
    testWidgets('long form choices fit narrow large-text $locale UI', (
      t,
    ) async {
      await t.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SizedBox(
                width: 260,
                child: GrammaticalFormChooser(
                  alternatives: const GrammaticalFormAlternatives(
                    before: '',
                    feminine: 'була дуже задоволена',
                    masculine: 'був дуже задоволений',
                    after: '',
                    subjectName: 'Bob',
                    subjectIsViewer: true,
                  ),
                  onSelected: (_) async {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(t.takeException(), isNull);
      final l10n = AppLocalizations.of(
        t.element(find.byType(GrammaticalFormChooser)),
      );
      expect(find.text(l10n.formFeminine.toLowerCase()), findsOneWidget);
      expect(find.text(l10n.formMasculine.toLowerCase()), findsOneWidget);
      for (final button in find.byType(OutlinedButton).evaluate()) {
        final rect = t.getRect(find.byWidget(button.widget));
        expect(rect.right, lessThanOrEqualTo(260));
        expect(rect.height, greaterThanOrEqualTo(44));
      }
    });
  }
}
