import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'chat_screen_primary_known_language_test.dart' as journey;
import 'contextual_word_help_fixture.dart';

void main() {
  testWidgets(
    'reported word meanings stay independent across viewer preferences',
    (tester) async {
      await journey.runContextualWordHelpJourney(
        tester,
        jsonDecode(contextualWordHelpFixture) as Map<String, dynamic>,
      );
    },
  );
}
