import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';

/// Composer edits use the same grapheme budget as typed input (US-036).
bool insertComposerEmoji(
  TextEditingController controller,
  String emoji, {
  required int maxLength,
}) {
  final text = controller.text;
  final selection = controller.selection;
  final start = selection.isValid
      ? selection.start.clamp(0, text.length)
      : text.length;
  final end = selection.isValid
      ? selection.end.clamp(start, text.length)
      : start;
  final next = text.replaceRange(start, end, emoji);
  if (next.characters.length > maxLength) return false;
  controller.value = TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: start + emoji.length),
  );
  return true;
}

void backspaceComposerEmoji(TextEditingController controller) {
  final text = controller.text;
  final selection = controller.selection;
  final end = selection.isValid
      ? selection.end.clamp(0, text.length)
      : text.length;
  var start = selection.isValid ? selection.start.clamp(0, end) : end;
  if (start == end) {
    if (start == 0) return;
    // Never leave a partial skin tone, flag, or joined family behind.
    start -= text.substring(0, start).characters.last.length;
  }
  controller.value = TextEditingValue(
    text: text.replaceRange(start, end, ''),
    selection: TextSelection.collapsed(offset: start),
  );
}

class ComposerEmojiPanel extends StatelessWidget {
  const ComposerEmojiPanel({
    super.key,
    required this.controller,
    required this.maxLength,
    required this.height,
    this.onSearchChanged,
  });

  final TextEditingController controller;
  final int maxLength;
  final double height;
  final ValueChanged<bool>? onSearchChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('composer-emoji-panel'),
    height: height,
    child: EmojiPicker(
      onEmojiSelected: (_, emoji) =>
          insertComposerEmoji(controller, emoji.emoji, maxLength: maxLength),
      onBackspacePressed: () => backspaceComposerEmoji(controller),
      config: Config(
        height: height,
        locale: Localizations.localeOf(context),
        emojiViewConfig: const EmojiViewConfig(
          columns: 8,
          emojiSizeMax: 28,
          backgroundColor: BlabColors.chatSurface,
        ),
        categoryViewConfig: const CategoryViewConfig(
          initCategory: Category.SMILEYS,
          backgroundColor: BlabColors.chatSurface,
          indicatorColor: BlabColors.brand,
          iconColorSelected: BlabColors.brand,
          backspaceColor: BlabColors.brand,
        ),
        searchViewConfig: SearchViewConfig(
          customSearchView: (config, state, showEmojiView) =>
              DefaultSearchView(config, state, () {
                onSearchChanged?.call(false);
                showEmojiView();
              }),
          hintText: context.l10n.searchEmoji,
          backgroundColor: BlabColors.chatSurface,
          buttonIconColor: BlabColors.warmMuted,
        ),
        bottomActionBarConfig: BottomActionBarConfig(
          customBottomActionBar: (config, state, showSearchView) =>
              DefaultBottomActionBar(config, state, () {
                onSearchChanged?.call(true);
                showSearchView();
              }),
          backgroundColor: BlabColors.chatSurface,
          buttonColor: BlabColors.chatSurface,
          buttonIconColor: BlabColors.brand,
        ),
      ),
    ),
  );
}
