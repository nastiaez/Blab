import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/widgets/full_emoji_picker_sheet.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens an EmojiPicker and forwards the selected emoji', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showFullEmojiPickerSheet(
                context,
                interfaceLanguageCode: 'en',
                onPick: (emoji) => picked = emoji,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final picker = tester.widget<EmojiPicker>(find.byType(EmojiPicker));
    expect(picker.onEmojiSelected, isNotNull);

    picker.onEmojiSelected!(null, const Emoji('🎉', 'party popper'));
    await tester.pumpAndSettle();

    expect(picked, '🎉');
    expect(find.byType(EmojiPicker), findsNothing);
  });

  testWidgets('search runs in the interface language, not always English', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showFullEmojiPickerSheet(
                context,
                interfaceLanguageCode: 'de',
                onPick: (_) {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final picker = tester.widget<EmojiPicker>(find.byType(EmojiPicker));
    expect(picker.config.locale, const Locale('de'));
    expect(picker.config.searchViewConfig.hintText, isNotEmpty);
  });

  testWidgets('uses the approved warm sheet surface throughout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: blabTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showFullEmojiPickerSheet(
                context,
                interfaceLanguageCode: 'en',
                onPick: (_) {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    final picker = tester.widget<EmojiPicker>(find.byType(EmojiPicker));
    expect(sheet.backgroundColor, BlabColors.chatSurface);
    expect(
      picker.config.emojiViewConfig.backgroundColor,
      BlabColors.chatSurface,
    );
    expect(
      picker.config.categoryViewConfig.backgroundColor,
      BlabColors.chatSurface,
    );
    expect(
      picker.config.searchViewConfig.backgroundColor,
      BlabColors.chatSurface,
    );
    expect(
      picker.config.bottomActionBarConfig.backgroundColor,
      BlabColors.chatSurface,
    );
    expect(
      picker.config.bottomActionBarConfig.buttonColor,
      BlabColors.chatSurface,
    );
  });
}
