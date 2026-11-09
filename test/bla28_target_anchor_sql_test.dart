import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:blab/features/chat/widgets/inline_correction_text.dart';
import 'bla28_integrated_provenance_test.dart' as fixture;

void main() {
  const directory = String.fromEnvironment('BLA28_SQL_EVIDENCE');
  testWidgets(
    'actual disposable PostgreSQL a-v2 roundtrip renders whole target',
    (tester) async {
      final raw =
          jsonDecode(File('$directory/explicit.json').readAsStringSync())
              as Map<String, dynamic>;
      final value = await fixture.decode(raw);
      expect(value.generationEnvelope?['version'], 'a-v2');
      expect(
        value.authoredCorrection?['targetText'],
        'Ich bin müde; sie ist beschäftigt.',
      );
      await tester.pumpWidget(fixture.host(value));
      final inline = tester.widget<InlineCorrectionText>(
        find.byType(InlineCorrectionText),
      );
      expect(
        inline.segments!.where((s) => !s.struck).map((s) => s.text).join(),
        'Ich bin müde; sie ist beschäftigt.',
      );
      expect(inline.segments!.where((s) => s.struck).single.text, 'ist');
      expect(inline.segments!.where((s) => s.corrected).single.text, 'bin');
    },
    skip: directory.isEmpty,
  );
}
