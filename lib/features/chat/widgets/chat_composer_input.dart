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
    this.showAttachment = true,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final int maxLength;
  final String attachTooltip;
  final VoidCallback onAttach;
  final bool showAttachment;
  final bool autofocus;

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
          Expanded(
            child: TextField(
              key: const ValueKey('composer-message-text-field'),
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (showAttachment) ...[
            const SizedBox(width: 2),
            IconButton(
              key: const ValueKey('composer-attach-button'),
              tooltip: attachTooltip,
              icon: const BlabIcon(
                name: 'media-image - 20',
                color: BlabColors.bubbleInk,
                size: 20,
              ),
              onPressed: onAttach,
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
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: canSend ? onSend : null,
              child: Center(
                child: Tooltip(
                  message: tooltip,
                  child: const SizedBox(
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
          ),
        ),
      ),
    );
  }
}
