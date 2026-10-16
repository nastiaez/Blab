import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/chat_screen_primary_known_language_test.dart' as journey;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('stationary translation and Connecting review', (tester) async {
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    Future<void> capture(String name) async {
      await tester.pump();
      final bytes = await binding.takeScreenshot(name);
      final path = '${Directory.systemTemp.path}/blab-$name.png';
      await File(path).writeAsBytes(bytes);
      debugPrint('MOTION_SCREENSHOT: $path');
      await tester.pump(const Duration(seconds: 1));
    }

    await journey.runStationaryTranslationJourney(tester, capture: capture);
    await journey.runStationaryTranslationJourney(
      tester,
      connecting: true,
      capture: (name) async {
        expect(find.text('Connecting…'), findsOneWidget);
        expect(find.text('No connection'), findsNothing);
        await capture('banner-$name');
      },
    );
  });
}
