import 'dart:io';

import 'package:blab/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('signed-out native introduction reaches email authentication', (
    tester,
  ) async {
    await app.main();
    if (Platform.isAndroid) {
      await binding.convertFlutterSurfaceToImage();
    }
    Future<void> waitFor(Finder finder) async {
      for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
      expect(finder, findsWidgets);
    }

    Future<void> capture(String name) async {
      await tester.pump(const Duration(milliseconds: 300));
      final bytes = await binding.takeScreenshot(name);
      await File(
        '${Directory.systemTemp.path}/blab-qa-$name.png',
      ).writeAsBytes(bytes);
    }

    await waitFor(find.byKey(const Key('welcome-reading-nook-illustration')));
    await capture('01-welcome');
    await tester.tap(find.text('Get started'));
    await tester.pump(const Duration(seconds: 1));
    await waitFor(find.byKey(const Key('learning-incoming-message')));
    final popup = find.byKey(const Key('vocabulary-popup'));
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (tester.widget<AnimatedOpacity>(popup).opacity == 1) break;
    }
    expect(tester.widget<AnimatedOpacity>(popup).opacity, 1);
    await capture('02-learn');
    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(seconds: 1));
    await waitFor(find.text('Continue with Google'));
    if (Platform.isIOS) {
      expect(find.text('Continue with Apple'), findsOneWidget);
    }
    await capture('03-signup');
    await tester.tap(find.text('Continue with email'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(TextField), findsAtLeastNWidgets(2));
    await capture('04-email');
  });
}
