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
    expect(find.text('Add a caption...'), findsOneWidget);
    expect(find.text('Pallavi Sen'), findsOneWidget);
    expect(find.byKey(const ValueKey('photo-preview-send')), findsOneWidget);

    final imageCenter = tester.getCenter(
      find.byKey(const ValueKey('photo-preview-image')),
    );
    final captionTop = tester.getTopLeft(
      find.byKey(const ValueKey('photo-preview-caption')),
    );
    expect(imageCenter.dy, lessThan(captionTop.dy));
  });
}
