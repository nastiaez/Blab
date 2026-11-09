// Visual-only native correction fixture. Prior108 real-backend evidence is separate.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/profile/edit_photo_screen.dart';
import 'package:blab/features/profile/crop_profile_photo_screen.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/state/profile_state.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('19075 native visual-only frozen photo states', (tester) async {
    String? baselinePhoto;
    final bytes = Uint8List.fromList(
      base64Decode(const String.fromEnvironment('QA_PHOTO_BASE64')),
    );
    Future<void> shot(String state) async {
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 650));
      final c = HttpClient();
      final request = await c.getUrl(
        Uri.parse(
          'http://${Platform.isAndroid ? '10.0.2.2' : '127.0.0.1'}:19175/${Platform.isAndroid ? 'android' : 'ios'}/$state',
        ),
      );
      final response = await request.close();
      await response.drain<void>();
      c.close();
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentProfileProvider.overrideWith(
            (_) async =>
                UserProfile(displayName: 'Nastia', avatarUrl: baselinePhoto),
          ),
          profilePhotoPickerProvider.overrideWithValue(
            (_) async => XFile.fromData(bytes, mimeType: 'image/jpeg'),
          ),
          updateAvatarActionProvider.overrideWithValue(
            (_) async => throw StateError('Visual fixture must not save'),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: blabTheme,
          home: const EditPhotoScreen(),
        ),
      ),
    );
    await shot('02-empty');
    await tester.tap(find.text('Photo'));
    for (
      var i = 0;
      i < 100 && find.byType(CropProfilePhotoScreen).evaluate().isEmpty;
      i++
    ) {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(find.byType(CropProfilePhotoScreen), findsOneWidget);
    await shot('03-crop');
    expect(tester.getRect(find.byTooltip('Confirm crop')).center.dy, 784);
    await tester.tap(find.byTooltip('Confirm crop'));
    for (
      var i = 0;
      i < 100 && find.byType(CropProfilePhotoScreen).evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await shot('04-selected');
    expect(
      tester.widget<Text>(find.text('Save')).style!.color,
      const Color(0xfff88c5a),
    );
    // State05 has a previously saved original, unlike deleting a new empty-profile draft.
    // The draft masks this fixture URL before removal; removal masks it afterwards.
    baselinePhoto = 'http://127.0.0.1:19175/never-fetched-original.jpg';
    ProviderScope.containerOf(
      tester.element(find.byType(EditPhotoScreen)),
    ).invalidate(currentProfileProvider);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove photo'));
    await shot('05-removed');
    expect(
      tester.widget<Text>(find.text('Save')).style!.color,
      const Color(0xfff88c5a),
    );
  });
}
