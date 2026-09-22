import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Persistent recovery surface shown instead of the composer after the
/// current user blocks the chat partner.
class BlockedChatBar extends StatelessWidget {
  const BlockedChatBar({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onUnblock,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('blocked-chat-bar'),
      decoration: const BoxDecoration(
        color: BlabColors.chatSurface,
        border: Border(top: BorderSide(color: BlabColors.chatDivider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: BlabColors.textMuted,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey('blocked-chat-unblock'),
                onPressed: onUnblock,
                style: TextButton.styleFrom(
                  foregroundColor: BlabColors.brand,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(actionLabel, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
