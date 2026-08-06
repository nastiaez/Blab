import 'package:flutter/material.dart';

import '../../../app/theme.dart';

class ChatComposerInput extends StatelessWidget {
  const ChatComposerInput({
    super.key,
    required this.controller,
    required this.hintText,
    required this.maxLength,
    required this.attachTooltip,
    required this.onAttach,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hintText;
  final int maxLength;
  final String attachTooltip;
  final VoidCallback onAttach;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('composer-message-container'),
      decoration: BoxDecoration(
        color: BlabColors.phoneSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('composer-message-text-field'),
              controller: controller,
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
          const SizedBox(width: 2),
          IconButton(
            key: const ValueKey('composer-attach-button'),
            tooltip: attachTooltip,
            icon: const Icon(Icons.add, color: BlabColors.brand, size: 24),
            onPressed: onAttach,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}
