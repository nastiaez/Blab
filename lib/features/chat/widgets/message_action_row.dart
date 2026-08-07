import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/models/message.dart';
import '../message_actions.dart'
    show MessageAction, canEditMessage, canReplyToMessage;

/// Icon + label action row that replaces the composer, Messenger-style,
/// while a message is selected via long-press. Same eligibility rules as
/// the modal sheet it replaces.
class MessageActionRow extends StatelessWidget {
  const MessageActionRow({
    super.key,
    required this.message,
    required this.onAction,
    this.now,
  });

  final Message message;
  final void Function(MessageAction) onAction;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final isOut = message.isOutgoing;
    final canReply = canReplyToMessage(message);
    final canEdit = canEditMessage(message, now: now);
    final items = <_ActionItem>[
      if (canReply)
        _ActionItem(Icons.reply, context.l10n.reply, MessageAction.reply),
      if (canEdit)
        _ActionItem(
          Icons.edit_outlined,
          context.l10n.edit,
          MessageAction.edit,
        ),
      _ActionItem(Icons.copy_outlined, context.l10n.copy, MessageAction.copy),
      if (isOut)
        _ActionItem(
          Icons.delete_outline,
          context.l10n.delete,
          MessageAction.delete,
          destructive: true,
        ),
      if (!isOut)
        _ActionItem(
          Icons.flag_outlined,
          context.l10n.report,
          MessageAction.report,
          destructive: true,
        ),
    ];
    return Container(
      color: BlabColors.cream,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final item in items)
                _ActionButton(item: item, onTap: () => onAction(item.action)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionItem {
  const _ActionItem(
    this.icon,
    this.label,
    this.action, {
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final MessageAction action;
  final bool destructive;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.item, required this.onTap});

  final _ActionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = item.destructive
        ? const Color(0xFFEF4444)
        : BlabColors.textPrimary;
    return InkWell(
      key: ValueKey('message-action-${item.action.name}'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
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
