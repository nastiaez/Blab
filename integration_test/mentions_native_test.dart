import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/chat_screen_primary_known_language_test.dart' as journey;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('BLA-36 actual chat mention journey', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    await journey.runMentionsJourney(
      tester,
      capture: (name) async {
        await tester.pump();
        await binding.takeScreenshot(name);
      },
    );
  });
}
