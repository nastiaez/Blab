import 'package:flutter_test/flutter_test.dart';
import 'chat_screen_primary_known_language_test.dart' as journey;

void main() {
  for (final mode in ['normal', 'practice']) {
    for (final pending in [false, true]) {
      testWidgets(
        'BLA31 $mode pending=$pending preserves both directions after deletion',
        (tester) async {
          await journey.runBla31AppearanceJourney(
            tester,
            mode: mode,
            pending: pending,
          );
        },
      );
    }
  }
}
