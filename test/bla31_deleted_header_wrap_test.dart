import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'deleted identity uses complete two-line label in narrow iOS lane',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: blabTheme,
          home: Scaffold(
            body: SizedBox(
              width: 155,
              height: 56,
              child: ChatHeaderIdentity(
                name: 'Deleted account',
                deleted: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      final text = find.text('Deleted account');
      expect(tester.widget<Text>(text).maxLines, 2);
      final paragraph = tester.renderObject<RenderParagraph>(text);
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
