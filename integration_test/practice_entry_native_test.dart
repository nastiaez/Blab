import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/chat_screen_primary_known_language_test.dart' as journey;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('BLA-6 native practice entry journey', (tester) async {
    const motion = bool.fromEnvironment('BLAB_QA_MOTION');
    if (Platform.isAndroid && !motion) {
      await binding.convertFlutterSurfaceToImage();
    }
    await journey.runPracticeEntryJourney(
      tester,
      afterLogin: const bool.fromEnvironment('BLAB_QA_AFTER_LOGIN'),
      withPendingInvite: const bool.fromEnvironment('BLAB_QA_PENDING_INVITE'),
      capture: (name) async {
        await tester.pump();
        if (motion) {
          await tester.pump(const Duration(seconds: 1));
        } else {
          await binding.takeScreenshot(name);
        }
      },
    );
  });
}
