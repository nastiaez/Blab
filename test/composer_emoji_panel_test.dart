import 'package:blab/features/chat/widgets/composer_emoji_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('emoji insertion replaces selection and respects grapheme budget', () {
    final controller = TextEditingController(text: 'a👨‍👩‍👧‍👦b');
    addTearDown(controller.dispose);
    controller.selection = const TextSelection(baseOffset: 1, extentOffset: 12);
    expect(insertComposerEmoji(controller, '👍🏽', maxLength: 3), isTrue);
    expect(controller.text, 'a👍🏽b');
    expect(controller.selection.baseOffset, 5);
    expect(insertComposerEmoji(controller, '😀', maxLength: 3), isFalse);
    expect(controller.text, 'a👍🏽b');
    expect(controller.selection.baseOffset, 5);
  });

  test('backspace removes full joined emoji, flag, and selection', () {
    final controller = TextEditingController(text: 'a🇩🇪👨‍👩‍👧‍👦');
    addTearDown(controller.dispose);
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    backspaceComposerEmoji(controller);
    expect(controller.text, 'a🇩🇪');
    backspaceComposerEmoji(controller);
    expect(controller.text, 'a');
    controller.selection = const TextSelection(baseOffset: 0, extentOffset: 1);
    backspaceComposerEmoji(controller);
    expect(controller.text, '');
    backspaceComposerEmoji(controller);
    expect(controller.text, '');
  });
}
