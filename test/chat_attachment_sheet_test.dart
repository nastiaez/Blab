import 'package:blab/features/chat/services/chat_image_picker.dart';
import 'package:blab/features/chat/widgets/chat_attachment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host() {
  ChatImageSource? selected;
  return MaterialApp(
    home: Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const TextField(
            key: ValueKey('message-field'),
            decoration: InputDecoration(hintText: 'Message'),
          ),
          ChatAttachmentTray(
            onPick: (source) {
              selected = source;
            },
          ),
          Text('Selected: ${selected?.name ?? 'none'}'),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('attachment tray sits under the message field with two tiles', (
    tester,
  ) async {
    await tester.pumpWidget(_host());

    expect(find.byKey(const ValueKey('attachment-tile-gallery')), findsOne);
    expect(find.byKey(const ValueKey('attachment-tile-camera')), findsOne);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('attachment-tile-gallery')))
          .dy,
      greaterThan(
        tester.getBottomLeft(find.byKey(const ValueKey('message-field'))).dy,
      ),
    );
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Photo library'), findsNothing);
    expect(find.byKey(const ValueKey('attachment-sheet-handle')), findsNothing);
    expect(find.text('File'), findsNothing);
    expect(find.text('Poll'), findsNothing);
    expect(find.text('Contact'), findsNothing);
  });

  testWidgets('gallery and camera tiles return the picker source', (
    tester,
  ) async {
    ChatImageSource? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAttachmentTray(
            onPick: (source) {
              selected = source;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Camera'));
    await tester.pumpAndSettle();

    expect(selected, ChatImageSource.camera);
  });
}
