import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/chat_screen_primary_known_language_test.dart' as journey;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native Leave and swipe Delete journey', (tester) async {
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await journey.runChatLifecycleJourney(
      tester,
      capture: (name) async {
        await binding.takeScreenshot(name);
      },
    );
  });
}
