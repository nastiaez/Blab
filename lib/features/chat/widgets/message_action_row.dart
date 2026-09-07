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
  });

  final Message message;
  final void Function(MessageAction) onAction;
  final ChatMode mode;
  final bool hasOriginal;
  final bool canListen;
  final bool isOriginalVisible;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final actions = actionsForMessage(
      message,
      mode: mode,
      hasOriginal: hasOriginal,
      canListen: canListen,
      now: now,
    );
    final items = actions
        .map((action) => _itemFor(context, action, isOriginalVisible))
        .toList();
    return Container(
      decoration: const BoxDecoration(
        color: BlabColors.chatSurface,
        border: Border(top: BorderSide(color: BlabColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: kMessageActionRowMinHeight,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final item in items)
                Expanded(
                  child: _ActionButton(
                    item: item,
                    onTap: () => onAction(item.action),
                  ),
                ),
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
    final color = item.destructive
        ? const Color(0xFFEF4444)
        : BlabColors.bubbleInk;
    return InkWell(
      key: ValueKey('message-action-${item.action.name}'),
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlabIcon(name: item.iconName, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              item.label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.1,
                fontWeight: FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
