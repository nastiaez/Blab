import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// What the user picked from the failed-message sheet. PRD US-030.
enum FailedMessageAction { retry, delete }

/// Bottom sheet shown when a user taps a failed outgoing bubble. Offers
/// Retry (re-fire the send) and Delete (drop it). PRD US-030.
Future<void> showFailedMessageSheet(
  BuildContext context, {
  required void Function(FailedMessageAction) onAction,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    isScrollControlled: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BlabColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 6, 20, 6),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Message failed to send',
                    style: TextStyle(
                      fontSize: 13,
                      color: BlabColors.textMuted,
                    ),
                  ),
                ),
              ),
              _ActionRow(
                icon: Icons.refresh,
                label: 'Retry',
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  onAction(FailedMessageAction.retry);
                },
              ),
              _ActionRow(
                icon: Icons.delete_outline,
                label: 'Delete',
                destructive: true,
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  onAction(FailedMessageAction.delete);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color =
        destructive ? const Color(0xFFEF4444) : BlabColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
