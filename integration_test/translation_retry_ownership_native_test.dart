import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import '../test/chat_screen_primary_known_language_test.dart' as journey;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native failed translation reopen and explicit retry', (
    tester,
  ) async {
    await binding.convertFlutterSurfaceToImage();
    await journey.runRetryOwnershipJourney(
      tester,
      capture: (name) async {
        await tester.pump();
        final bytes = await binding.takeScreenshot(name);
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/$name.png';
        await File(path).writeAsBytes(bytes);
        print('RETRY_SCREENSHOT: $path');
      },
    );
  });
}
