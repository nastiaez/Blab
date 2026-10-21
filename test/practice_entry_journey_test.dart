import 'package:flutter_test/flutter_test.dart';
import 'chat_screen_primary_known_language_test.dart' as journey;

void main() {
  testWidgets('BLA-6 pending invitation after login waits for chat tap', (
    tester,
  ) async {
    await journey.runPracticeEntryJourney(
      tester,
      afterLogin: true,
      withPendingInvite: true,
    );
  });
  testWidgets('BLA-6 completed-account login does not open practice setup', (
    tester,
  ) async {
    await journey.runPracticeEntryJourney(tester, afterLogin: true);
  });
  testWidgets(
    'BLA-6 list, first entry, Back, failure, retry and reopen',
    journey.runPracticeEntryJourney,
  );
}
