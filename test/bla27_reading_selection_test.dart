import 'package:flutter_test/flutter_test.dart';
import 'chat_screen_primary_known_language_test.dart' as journey;

void main() {
  testWidgets('BLA27 original remains readable and scrollable with reactions', (
    tester,
  ) async {
    await journey.runBla27ReadingJourney(tester);
  });
}
