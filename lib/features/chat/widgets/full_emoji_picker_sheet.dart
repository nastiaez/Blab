import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';

/// Opened from the floating reaction row's "+" (and from tapping an
/// existing reaction badge) — the full emoji set with search, half the
/// screen height, standard drag-to-dismiss.
///
/// [interfaceLanguageCode] drives both the search hint and the picker's own
/// keyword matching, so search works in the language the app is set to.
Future<void> showFullEmojiPickerSheet(
  BuildContext context, {
  required void Function(String emoji) onPick,
  required String interfaceLanguageCode,
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
                    locale: Locale(interfaceLanguageCode),
                    emojiViewConfig: const EmojiViewConfig(
                      columns: 8,
                      emojiSizeMax: 28,
                      backgroundColor: Colors.white,
                    ),
                    categoryViewConfig: const CategoryViewConfig(
                      // Skip the "Recents" landing tab — on a fresh
                      // install (or after force-stop) it's always empty,
                      // so start on a populated category instead.
                      initCategory: Category.SMILEYS,
                      backgroundColor: Colors.white,
                      indicatorColor: BlabColors.brand,
                      iconColorSelected: BlabColors.brand,
                      backspaceColor: BlabColors.brand,
                    ),
                    searchViewConfig: SearchViewConfig(
                      hintText: sheetCtx.l10n.searchEmoji,
                      backgroundColor: Colors.white,
                      buttonIconColor: BlabColors.textMuted,
                    ),
                    bottomActionBarConfig: const BottomActionBarConfig(
                      backgroundColor: Colors.white,
                      buttonColor: Colors.white,
                      buttonIconColor: BlabColors.brand,
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
