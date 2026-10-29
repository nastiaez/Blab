import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/models/chat.dart';
import '../../../shared/models/message.dart';
import '../../../shared/widgets/blab_icon.dart';
import '../message_actions.dart' show MessageAction, actionsForMessage;

const double kMessageActionRowMinHeight = 66;

/// Icon + label action row that replaces the composer, Messenger-style,
/// while a message is selected via long-press. Same eligibility rules as
/// the modal sheet it replaces.
class MessageActionRow extends StatelessWidget {
  const MessageActionRow({
    super.key,
    required this.message,
    required this.onAction,
    this.mode = ChatMode.normal,
    this.hasOriginal = false,
    this.canListen = false,
    this.isOriginalVisible = false,
    this.now,
    this.readOnly = false,
  });

  final Message message;
  final void Function(MessageAction) onAction;
  final ChatMode mode;
  final bool hasOriginal;
  final bool canListen;
  final bool isOriginalVisible;
  final DateTime? now;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final actions = actionsForMessage(
      message,
      mode: mode,
      hasOriginal: hasOriginal,
      canListen: canListen,
      now: now,
    );
    final eligible = actions
        .where(
          (action) =>
              !readOnly ||
              ![
                MessageAction.reply,
                MessageAction.edit,
                MessageAction.delete,
              ].contains(action),
        )
        .toList();
    if (eligible.remove(MessageAction.listen)) {
      eligible.insert(0, MessageAction.listen);
    }
    final items = eligible
        .map((action) => _itemFor(context, action, isOriginalVisible))
        .toList();
    return Material(
      color: const Color(0xFFFFFCF8),
      borderRadius: BorderRadius.circular(20),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: SizedBox(
        width: 202,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  const Divider(
                    height: 0,
                    thickness: 1,
                    color: BlabColors.divider,
                  ),
                _ActionButton(
                  item: items[i],
                  onTap: () => onAction(items[i].action),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

_ActionItem _itemFor(
  BuildContext context,
  MessageAction action,
  bool isOriginalVisible,
) => switch (action) {
  MessageAction.reply => _ActionItem(
    'long-arrow-up-left - 16',
    context.l10n.reply,
    action,
  ),
  MessageAction.edit => _ActionItem(
    'edit-pencil - 16',
    context.l10n.edit,
    action,
  ),
  MessageAction.copy => _ActionItem('copy - 16', context.l10n.copy, action),
  MessageAction.original => _ActionItem(
    isOriginalVisible ? 'eye-closed - 16' : 'eye - 16',
    context.l10n.original,
    action,
  ),
  MessageAction.listen => _ActionItem(
    'sound-high - 16',
    context.l10n.listen,
    action,
  ),
  MessageAction.delete => _ActionItem(
    'trash - 16',
    context.l10n.delete,
    action,
    destructive: true,
  ),
  MessageAction.report => _ActionItem(
    'white-flag - 16',
    context.l10n.report,
    action,
  ),
};

class _ActionItem {
  const _ActionItem(
    this.iconName,
    this.label,
    this.action, {
    this.destructive = false,
  });

  final String iconName;
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
    final color = item.destructive ? BlabColors.error : BlabColors.bubbleInk;
    return InkWell(
      key: ValueKey('message-action-${item.action.name}'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              BlabIcon(name: item.iconName, size: 16, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
