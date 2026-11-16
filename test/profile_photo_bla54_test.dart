import 'dart:async';
import 'dart:typed_data';
import 'package:blab/features/profile/crop_profile_photo_screen.dart';
import 'package:blab/features/profile/edit_photo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'profile_photo_ui_test.dart' as fixtures;
import 'package:blab/shared/widgets/blab_icon.dart';
import 'package:blab/shared/widgets/navigation/blab_app_bar.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

void main() {
  testWidgets('preparation and crop share identical frozen header chrome', (
    tester,
  ) async {
    final pending = Completer<XFile?>();
    await fixtures.pump(
      tester,
      const EditPhotoScreen(),
      picker: (_) => pending.future,
    );
    await tester.tap(find.text('Photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    (Rect, Rect) checkHeader() {
      final bar = tester.widget<BlabAppBar>(find.byType(BlabAppBar).last);
      final title = bar.title! as Text;
      expect(title.data, 'Crop photo');
      expect(title.style?.fontSize, 17);
      expect(title.style?.fontWeight, FontWeight.w700);
      expect(title.style?.color, Colors.white);
      expect(bar.backgroundColor, Colors.black);
      expect(bar.foregroundColor, Colors.white);
      expect(bar.centerTitle, isTrue);
      expect(bar.systemOverlayStyle, SystemUiOverlayStyle.light);
      final back = bar.leading! as IconButton;
      expect(back.onPressed, isNotNull);
      final icon = back.icon as BlabIcon;
      expect(icon.name, 'nav-arrow-left - 20');
      expect(icon.size, 20);
      expect(icon.color, Colors.white);
      return (
        tester.getRect(find.byWidget(title)),
        tester.getRect(find.byWidget(back)),
      );
    }

    final preparing = checkHeader();
    pending.complete(null);
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsOneWidget);
    await fixtures.pump(
      tester,
      CropProfilePhotoScreen(bytes: fixtures.fixture()),
      picker: (_) => pending.future,
    );
    expect(checkHeader(), preparing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('picker failure restores usable editor with localized error', (
    tester,
  ) async {
    await fixtures.pump(
      tester,
      const EditPhotoScreen(),
      picker: (_) async => throw StateError('picker unavailable'),
    );
    await tester.tap(find.text('Photo'));
    await tester.pumpAndSettle();
    expect(find.byType(PickProfilePhotoScreen), findsNothing);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'late picker cancellation after route removal leaves editor intact',
    (tester) async {
      final pending = Completer<XFile?>();
      await fixtures.pump(
        tester,
        const EditPhotoScreen(),
        picker: (_) => pending.future,
      );
      await tester.tap(find.text('Photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final context = tester.element(find.byType(PickProfilePhotoScreen));
      Navigator.of(context).pop();
      await tester.pump(const Duration(milliseconds: 200));
      pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Camera'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final size in [
    const Size(200, 200),
    const Size(200, 400),
    const Size(400, 200),
  ]) {
    testWidgets('minimum zoom touches circle and pan stays covered $size', (
      tester,
    ) async {
      final bytes = Uint8List.fromList(
        img.encodeJpg(
          img.Image(width: size.width.toInt(), height: size.height.toInt()),
        ),
      );
      await fixtures.pump(tester, CropProfilePhotoScreen(bytes: bytes));
      final canvas = tester.getRect(
        find.byKey(const ValueKey('profile-crop-gesture')),
      );
      final image = tester.getRect(find.byType(Image));
      expect(image.size.shortestSide, closeTo(canvas.width - 24, .001));
      await tester.drag(
        find.byKey(const ValueKey('profile-crop-gesture')),
        const Offset(1000, 1000),
      );
      await tester.pump();
      final moved = tester.getRect(find.byType(Image));
      final circle = canvas.deflate(12);
      expect(moved.left, lessThanOrEqualTo(circle.left + .001));
      expect(moved.top, lessThanOrEqualTo(circle.top + .001));
      expect(moved.right, greaterThanOrEqualTo(circle.right - .001));
      expect(moved.bottom, greaterThanOrEqualTo(circle.bottom - .001));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'picker and preparation stay on black crop route, cancel restores editor',
    (tester) async {
      final pending = Completer<XFile?>();
      await fixtures.pump(
        tester,
        const EditPhotoScreen(),
        picker: (_) => pending.future,
      );
      await tester.tap(find.text('Photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(PickProfilePhotoScreen), findsOneWidget);
      expect(find.text('Camera'), findsNothing);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold).last).backgroundColor,
        Colors.black,
      );
      pending.complete(null);
      await tester.pumpAndSettle();
      expect(find.text('Camera'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
