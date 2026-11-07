import 'package:blab/shared/widgets/blab_icon.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:typed_data';
import 'dart:async';
import 'package:blab/app/theme.dart';
import 'package:blab/features/profile/edit_profile_screen.dart';
import 'package:blab/features/profile/edit_photo_screen.dart';
import 'package:blab/features/profile/crop_profile_photo_screen.dart';
import 'package:blab/shared/services/profile_service.dart';
import 'package:blab/shared/state/profile_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List fixture() {
  final image = img.Image(width: 400, height: 200);
  img.fillRect(
    image,
    x1: 0,
    y1: 0,
    x2: 199,
    y2: 199,
    color: img.ColorRgb8(255, 0, 0),
  );
  img.fillRect(
    image,
    x1: 200,
    y1: 0,
    x2: 399,
    y2: 199,
    color: img.ColorRgb8(0, 0, 255),
  );
  return Uint8List.fromList(img.encodeJpg(image));
}

Future<void> pump(
  WidgetTester tester,
  Widget child, {
  String? url,
  Future<void> Function(Uint8List?)? save,
  ProfilePhotoPicker? picker,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentProfileProvider.overrideWith(
          (_) async => UserProfile(displayName: 'Nastia', avatarUrl: url),
        ),
        updateAvatarActionProvider.overrideWithValue(save ?? (_) async {}),
        if (picker != null)
          profilePhotoPickerProvider.overrideWithValue(picker),
      ],
      child: MaterialApp(theme: blabTheme, home: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'normalization rejects malformed images and crops actual selected pixels',
    () async {
      await expectLater(
        prepareProfilePhoto(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      final normalized = await prepareProfilePhoto(fixture());
      final left = img.decodeJpg(
        cropProfilePhotoPixels(normalized, const Rect.fromLTWH(0, 0, 200, 200)),
      )!;
      final right = img.decodeJpg(
        cropProfilePhotoPixels(
          normalized,
          const Rect.fromLTWH(200, 0, 200, 200),
        ),
      )!;
      expect(left.width, 512);
      expect(left.getPixel(256, 256).r, greaterThan(240));
      expect(right.getPixel(256, 256).b, greaterThan(240));
    },
  );
  testWidgets('entry has one actual name and separate pencil navigation', (
    tester,
  ) async {
    await pump(tester, const EditProfileScreen());
    expect(find.text('Nastia'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    await tester.tap(find.byTooltip('Edit photo'));
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Photo'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
          .onPressed,
      isNull,
    );
  });
  testWidgets('remove is only a draft until explicit Save', (tester) async {
    var calls = 0;
    Uint8List? saved = Uint8List(1);
    await pump(
      tester,
      const EditPhotoScreen(),
      url: 'https://example.invalid/avatar.jpg',
      save: (bytes) async {
        calls++;
        saved = bytes;
      },
    );
    await tester.tap(find.byTooltip('Remove photo'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byTooltip('Remove photo'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(saved, isNull);
  });
  testWidgets('crop has real draggable preview and icon-only confirmation', (
    tester,
  ) async {
    final bytes = (await tester.runAsync(
      () => prepareProfilePhoto(fixture()),
    ))!;
    await pump(tester, CropProfilePhotoScreen(bytes: bytes));
    expect(find.text('Done'), findsNothing);
    expect(find.byTooltip('Confirm crop'), findsOneWidget);
    final before = tester.getTopLeft(find.byType(Image));
    await tester.drag(
      find.byKey(const ValueKey('profile-crop-gesture')),
      const Offset(40, 0),
    );
    await tester.pump();
    expect(tester.getTopLeft(find.byType(Image)).dx, greaterThan(before.dx));
    expect(tester.takeException(), isNull);
  });
  testWidgets('Back discards removal without invoking persistence', (
    tester,
  ) async {
    var calls = 0;
    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const EditPhotoScreen()),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
      url: 'https://example.invalid/avatar.jpg',
      save: (_) async {
        calls++;
      },
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove photo'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (w) => w is BlabIcon && w.name == 'nav-arrow-left - 20',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(calls, 0);
  });
  testWidgets(
    'failed Save retains draft and blocks duplicate pending requests',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await pump(
        tester,
        const EditPhotoScreen(),
        url: 'https://example.invalid/avatar.jpg',
        save: (_) {
          calls++;
          return pending.future;
        },
      );
      await tester.tap(find.byTooltip('Remove photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(calls, 1);
      expect(
        tester
            .widget<IconButton>(
              find.ancestor(
                of: find.byWidgetPredicate(
                  (w) => w is BlabIcon && w.name == 'nav-arrow-left - 20',
                ),
                matching: find.byType(IconButton),
              ),
            )
            .onPressed,
        isNull,
      );
      pending.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not update your profile. Try again.'),
        findsOneWidget,
      );
      expect(find.byTooltip('Remove photo'), findsNothing);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNotNull,
      );
    },
  );
  testWidgets('avatar overlay uses exactly 20px glyph within 44px circle', (
    tester,
  ) async {
    await pump(tester, const EditProfileScreen());
    final glyph = find.descendant(
      of: find.byTooltip('Edit photo'),
      matching: find.byType(SvgPicture),
    );
    expect(tester.getSize(glyph), const Size(20, 20));
    expect(find.text('N'), findsOneWidget);
    expect(find.text('NA'), findsNothing);
  });
  testWidgets(
    'native Camera/Photo cancellations preserve saved photo and clean draft',
    (tester) async {
      final sources = <ImageSource>[];
      await pump(
        tester,
        const EditPhotoScreen(),
        url: 'https://example.invalid/avatar.jpg',
        picker: (source) async {
          sources.add(source);
          return null;
        },
      );
      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Photo'));
      await tester.pumpAndSettle();
      expect(sources, [ImageSource.camera, ImageSource.gallery]);
      expect(find.byTooltip('Remove photo'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNull,
      );
    },
  );
  testWidgets(
    'unavailable native source reports localized recovery without modifying saved photo',
    (tester) async {
      await pump(
        tester,
        const EditPhotoScreen(),
        url: 'https://example.invalid/avatar.jpg',
        picker: (_) async => throw StateError('unavailable'),
      );
      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byTooltip('Remove photo'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
            .onPressed,
        isNull,
      );
    },
  );
}
