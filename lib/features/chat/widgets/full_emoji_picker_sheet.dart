import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

/// Opened from the floating reaction row's "+" (and from tapping an
/// existing reaction badge) — the full emoji set with search, half the
/// screen height, standard drag-to-dismiss.
Future<void> showFullEmojiPickerSheet(
  BuildContext context, {
  required void Function(String emoji) onPick,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      final sheetHeight = MediaQuery.sizeOf(sheetCtx).height * 0.5;
      return SafeArea(
        top: false,
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4DCCC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    Navigator.of(sheetCtx).pop();
                    onPick(emoji.emoji);
                  },
                  config: Config(
                    height: sheetHeight,
                    emojiViewConfig: const EmojiViewConfig(
                      columns: 8,
                      emojiSizeMax: 28,
                    ),
                    searchViewConfig: const SearchViewConfig(
                      hintText: 'Search emoji',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
