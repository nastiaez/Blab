import '../../../shared/widgets/actions/blab_icon_button.dart';
import '../../../shared/widgets/forms/blab_composer_field.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/blab_icon.dart';

class ChatComposerInput extends StatelessWidget {
  const ChatComposerInput({
    super.key,
    required this.controller,
    this.focusNode,
    required this.hintText,
    required this.maxLength,
    required this.attachTooltip,
    required this.onAttach,
    this.enabled = true,
    this.showAttachment = true,
    this.autofocus = false,
    this.onToggleEmoji,
    this.onTapText,
    this.emojiPanelOpen = false,
    this.emojiTooltip,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final int maxLength;
  final String attachTooltip;
  final VoidCallback onAttach;
  final bool enabled;
  final bool showAttachment;
  final bool autofocus;
  final VoidCallback? onToggleEmoji, onTapText;
  final bool emojiPanelOpen;
  final String? emojiTooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('composer-message-container'),
      decoration: BoxDecoration(
        color: BlabColors.chatSurface,
        border: Border.all(color: BlabColors.chatDivider),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (onToggleEmoji != null)
            BlabIconButton(
              key: const ValueKey('composer-emoji-toggle'),
              tooltip: emojiTooltip,
              icon: BlabIcon(
                name: emojiPanelOpen ? 'keyboard - 20' : 'emoji-face - 20',
                color: BlabColors.bubbleInk,
                size: 20,
              ),
              onPressed: enabled ? onToggleEmoji : null,
            ),
          Expanded(
            child: BlabComposerField(
              fieldKey: const ValueKey('composer-message-text-field'),
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              autofocus: autofocus && !emojiPanelOpen,
              keyboardType: emojiPanelOpen
                  ? TextInputType.none
                  : TextInputType.multiline,
              onTap: onTapText,
              minLines: 1,
              maxLines: 5,
              maxLength: maxLength,
              // Hide the default counter; the chat input renders its own.
              buildCounter:
                  (
                    context, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => null,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                fontSize: 15,
                color: BlabColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: hintText,
                hintMaxLines: 1,
                hintStyle: const TextStyle(
                  color: BlabColors.textMuted,
                  fontSize: 15,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: onToggleEmoji == null ? 14 : 2,
                  vertical: 10,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (showAttachment) ...[
            const SizedBox(width: 2),
            BlabIconButton(
              key: const ValueKey('composer-attach-button'),
              tooltip: attachTooltip,
              icon: const BlabIcon(
                name: 'media-image - 20',
                color: BlabColors.bubbleInk,
                size: 20,
              ),
              onPressed: enabled ? onAttach : null,
              splashRadius: 20,
            ),
          ],
        ],
      ),
    );
  }
}

class ChatSendButton extends StatelessWidget {
  const ChatSendButton({
    super.key,
    required this.canSend,
    required this.isPractice,
    required this.tooltip,
    required this.onSend,
  });

  final bool canSend;
  final bool isPractice;
  final String tooltip;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: DecoratedBox(
        key: const ValueKey('composer-send-decoration'),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: isPractice
              ? const [
                  BoxShadow(
                    color: Color(0x2E231208),
                    offset: Offset(0, 3),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: AnimatedContainer(
          key: const ValueKey('composer-send-fill'),
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: canSend
                ? BlabColors.sendButton
                : BlabColors.sendButton.withValues(alpha: 0.4),
          ),
          child: BlabIconButton(
            tooltip: tooltip,
            onPressed: canSend ? onSend : null,
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(shape: const CircleBorder()),
            icon: const SizedBox(
              key: ValueKey('composer-send-icon'),
              width: 20,
              height: 20,
              child: BlabIcon(
                name: 'arrow-up - 20',
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
