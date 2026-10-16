import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/google_signin_handoff_test.dart' show runGoogleHandoffJourney;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native Google return reaches profile setup without restart', (
    tester,
  ) async {
    await runGoogleHandoffJourney(
      tester,
      capture: () async {
        if (Platform.isAndroid) {
          await binding.convertFlutterSurfaceToImage();
          await tester.pump();
        }
        final bytes = await binding.takeScreenshot(
          'google-return-confirm-name',
        );
        final path =
            '${Directory.systemTemp.path}/blab-google-return-confirm-name.png';
        await File(path).writeAsBytes(bytes);
        // Host collector copies evidence before Flutter removes its test app.
        debugPrint('GOOGLE_SCREENSHOT: $path');
        await Future<void>.delayed(const Duration(seconds: 2));
      },
    );
  });
}
