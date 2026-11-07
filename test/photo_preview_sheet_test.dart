import 'package:blab/shared/widgets/blab_icon.dart';
import 'dart:convert';
import 'dart:typed_data';

import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/widgets/photo_preview_sheet.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _onePixelPng() {
  return base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lx1P9QAAAABJRU5ErkJggg==',
  );
}

Widget _host() {
  return MaterialApp(
    theme: blabTheme,
    home: Scaffold(
      body: PhotoPreviewSheet(
        image: PickedChatImage(
          bytes: _onePixelPng(),
          mimeType: 'image/png',
          fileName: 'preview.png',
        ),
        recipientName: 'Pallavi Sen',
      ),
    ),
  );
}

void main() {
  testWidgets('photo preview uses a full-screen dark composer layout', (
    tester,
  ) async {
    await tester.pumpWidget(_host());

    final root = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('photo-preview-fullscreen')),
    );
    expect(root.color, Colors.black);
    expect(find.byKey(const ValueKey('photo-preview-close')), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-preview-image')), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-preview-caption')), findsOneWidget);
    expect(find.text('Add a caption…'), findsOneWidget);
    expect(find.text('Pallavi Sen'), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-preview-send')), findsOneWidget);
    final sendIcon = tester.widget<BlabIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('photo-preview-send')),
        matching: find.byType(BlabIcon),
      ),
    );
    expect(sendIcon.name, 'arrow-right - 20');
    expect(sendIcon.size, 20);
    for (final name in ['close - 20', 'media-image-plus - 20']) {
      expect(
        find.byWidgetPredicate(
          (w) => w is BlabIcon && w.name == name && w.size == 20,
        ),
        findsOneWidget,
      );
    }
    expect(find.byType(Icon), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('photo-preview-send'))),
      const Size(56, 56),
    );

    final imageCenter = tester.getCenter(
      find.byKey(const ValueKey('photo-preview-image')),
    );
    final captionTop = tester.getTopLeft(
      find.byKey(const ValueKey('photo-preview-caption')),
    );
    expect(imageCenter.dy, lessThan(captionTop.dy));
  });
}
