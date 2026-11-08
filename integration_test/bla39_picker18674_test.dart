import 'dart:convert';

import 'bla39_photo_fixture.dart';
import 'dart:io';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/profile/edit_profile_screen.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/state/profile_state.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'real OS picker with explicitly isolated in-memory persistence',
    (tester) async {
      var savedCalls = 0;
      Uint8List? saved;
      String? savedUrl;
      final imageServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      imageServer.listen((request) {
        request.response.headers.contentType = ContentType('image', 'jpeg');
        request.response.add(saved ?? base64Decode(bla39PhotoFixture));
        request.response.close();
      });
      addTearDown(() => imageServer.close(force: true));
      late final ProviderContainer root;
      root = ProviderContainer(
        overrides: [
          currentProfileProvider.overrideWith(
            (_) async =>
                UserProfile(displayName: 'Nastia', avatarUrl: savedUrl),
          ),
          updateAvatarActionProvider.overrideWithValue((bytes) async {
            savedCalls++;
            saved = bytes;
            savedUrl = bytes == null
                ? null
                : Uri(
                    scheme: 'http',
                    host: '127.0.0.1',
                    port: imageServer.port,
                    path: '/avatar.jpg',
                    queryParameters: {'v': savedCalls.toString()},
                  ).toString();
            root.invalidate(currentProfileProvider);
          }),
        ],
      );
      addTearDown(root.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: root,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: blabTheme,
            home: const EditProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (Platform.isAndroid || Platform.isIOS) {
        await binding.convertFlutterSurfaceToImage();
        await tester.pumpAndSettle();
      }
      await binding.takeScreenshot('01-entry');
      await tester.tap(find.byTooltip('Edit photo'));
      await tester.pumpAndSettle();
      await binding.takeScreenshot('02-empty');
      await tester.tap(find.text('Photo'));
      await tester.pump();
      // Real OS picker selection is driven externally after this marker.
      debugPrint('BLA39_NATIVE_PICKER_OPEN');
      if (Platform.isAndroid || Platform.isIOS) {
        await Future<void>.delayed(const Duration(seconds: 35));
      }
      await tester.pumpAndSettle();
      expect(find.text('Crop photo'), findsOneWidget);
      await binding.takeScreenshot('03-crop');
      await tester.drag(
        find.byKey(const ValueKey('profile-crop-gesture')),
        const Offset(22, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Confirm crop'));
      await tester.pumpAndSettle();
      expect(savedCalls, 0);
      await binding.takeScreenshot('04-selected-unsaved');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(savedCalls, 1);
      expect(saved, isNotNull);
      expect(find.text('Edit profile'), findsOneWidget);
      await binding.takeScreenshot('06-saved-photo-entry');
      await tester.tap(find.byTooltip('Edit photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove photo'));
      await tester.pumpAndSettle();
      expect(savedCalls, 1);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNotNull,
      );
      await binding.takeScreenshot('05-removed-unsaved');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(savedCalls, 2);
      expect(saved, isNull);
      await binding.takeScreenshot('07-saved-removal-entry');
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
