import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/models/message.dart';

/// The action picked from the long-press sheet. PRD US-019, US-020.
enum MessageAction { reply, edit, copy, delete }

/// Show the long-press action sheet for [message]. Outgoing messages get
/// Reply / Edit / Copy / Delete; incoming get Reply / Copy only.
///
/// The sheet pops itself before invoking [onAction], so callers can safely
/// push subsequent UI (SnackBars, modal sheets) without worrying about a
/// stacked route.
Future<void> showMessageActionSheet(
  BuildContext context, {
  required Message message,
  required void Function(MessageAction) onAction,
}) {
  final isOut = message.isOutgoing;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    isScrollControlled: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) {
      final rows = <Widget>[
        _ActionRow(
          icon: Icons.reply,
          label: 'Reply',
          onTap: () {
            Navigator.of(sheetCtx).pop();
            onAction(MessageAction.reply);
          },
        ),
        if (isOut)
          _ActionRow(
            icon: Icons.edit_outlined,
            label: 'Edit',
            onTap: () {
              Navigator.of(sheetCtx).pop();
              onAction(MessageAction.edit);
            },
          ),
        _ActionRow(
          icon: Icons.copy_outlined,
          label: 'Copy',
          onTap: () {
            Navigator.of(sheetCtx).pop();
            onAction(MessageAction.copy);
          },
        ),
        if (isOut)
          _ActionRow(
            icon: Icons.delete_outline,
            label: 'Delete',
            destructive: true,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              onAction(MessageAction.delete);
            },
          ),
      ];

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              // Drag handle pill.
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BlabColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ...rows,
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
    final color = destructive
        ? const Color(0xFFEF4444)
        : BlabColors.textPrimary;
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
