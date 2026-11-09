import 'dart:convert';
import 'dart:io';
import 'package:blab/features/chat/widgets/inline_correction_text.dart';
import 'package:blab/features/chat/widgets/message_text.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'bla28_integrated_provenance_test.dart' as fixture;

void main() {
  const directory = String.fromEnvironment('BLA28_SQL_EVIDENCE');
  // These files are returned by actual PostgreSQL inserts, updates and selects.
  // Explicit opt-in keeps the portable suite independent of host evidence paths.
  for (final name in [
    'explicit',
    'empty',
    'stripped',
    'envelope-null',
    'envelope-string',
    'envelope-array',
    'envelope-empty',
    'envelope-stale',
    'envelope-unknown',
    'missing-provenance',
    'top-valid',
    'top-null',
    'top-false',
    'top-zero',
    'top-string',
    'top-array',
    'optional-metadata',
    'form',
  ]) {
    testWidgets(
      'real SQL saved/loaded $name uses production parser and renderer',
      (tester) async {
        final raw =
            jsonDecode(File('$directory/$name.json').readAsStringSync())
                as Map<String, dynamic>;
        // Serialization boundary used by older transport/cache clients.
        final value = await fixture.decode(
          jsonDecode(jsonEncode(raw)) as Map<String, dynamic>,
        );
        expect(value.sourceScopedGeneration, isTrue);
        await tester.pumpWidget(fixture.host(value));
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is MessageText &&
                w.text == 'Ich bin müde; sie ist beschäftigt.',
          ),
          findsOneWidget,
        );
        final inlines = tester.widgetList<InlineCorrectionText>(
          find.byType(InlineCorrectionText),
        );
        final struck = inlines
            .expand((w) => w.segments ?? <CorrectionSegment>[])
            .where((s) => s.struck)
            .map((s) => s.text)
            .toList();
        final corrected = inlines
            .expand((w) => w.segments ?? <CorrectionSegment>[])
            .where((s) => s.corrected)
            .map((s) => s.text)
            .toList();
        if (name == 'explicit' || name == 'form') {
          expect(struck, ['ist']);
          expect(corrected, ['bin']);
        } else {
          expect(struck, isEmpty);
          expect(corrected, isEmpty);
        }
        expect(struck, isNot(contains('tired')));
        expect(corrected, isNot(contains('müde')));
        expect(tester.takeException(), isNull);
      },
      skip: directory.isEmpty,
    );
  }
  test(
    'malformed discriminator presence survives parser compatibility boundary',
    () {
      for (final raw in [null, false, 0, '', [], {}]) {
        expect(parseGenerationEnvelope({'generationEnvelope': raw}), isNotNull);
        expect(
          parseGenerationEnvelope({
            'form_alternatives': {'blabGenerationEnvelope': raw},
          }),
          isNotNull,
        );
      }
      expect(parseGenerationEnvelope({'tokens': []}), isNull);
    },
  );
}
