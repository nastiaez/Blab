import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/models/message.dart';

/// The action picked from the long-press sheet. PRD US-019, US-020;
/// `report` added for Step 3.6a.
enum MessageAction { reply, edit, copy, delete, report }

const Duration messageEditWindow = Duration(hours: 24);
const double kMessageActionSheetMaxWidth = 360;
const List<String> kQuickMessageReactions = [
  '❤️',
  '😂',
  '👍',
  '😮',
  '😢',
  '🙌',
];
const List<String> kMoreMessageReactions = [
  '🔥',
  '🥰',
  '👏',
  '🙏',
  '😍',
  '🤔',
  '😎',
  '😭',
  '😆',
  '👌',
  '💯',
  '✨',
];

bool canReplyToMessage(Message message) =>
    message.status == MessageStatus.delivered ||
    message.status == MessageStatus.read;

bool canEditMessage(Message message, {DateTime? now}) {
  if (!message.isOutgoing || !canReplyToMessage(message)) return false;
  final age = (now ?? DateTime.now()).toUtc().difference(
    message.sentAt.toUtc(),
  );
  return age <= messageEditWindow;
}

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
  void Function(String emoji)? onReact,
  DateTime? now,
}) {
  final isOut = message.isOutgoing;
  final canReply = canReplyToMessage(message);
  final canEdit = canEditMessage(message, now: now);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    elevation: 0,
    isScrollControlled: true,
    builder: (sheetCtx) {
      final rows = <Widget>[
        if (canReply)
          _ActionRow(
            icon: Icons.reply,
            label: context.l10n.reply,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              onAction(MessageAction.reply);
            },
          ),
        if (canEdit)
          _ActionRow(
            icon: Icons.edit_outlined,
            label: context.l10n.edit,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              onAction(MessageAction.edit);
            },
          ),
        _ActionRow(
          icon: Icons.copy_outlined,
          label: context.l10n.copy,
          onTap: () {
            Navigator.of(sheetCtx).pop();
            onAction(MessageAction.copy);
          },
        ),
        if (isOut)
          _ActionRow(
            icon: Icons.delete_outline,
            label: context.l10n.delete,
            destructive: true,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              onAction(MessageAction.delete);
            },
          ),
        // Report only makes sense for the other person's messages.
        if (!isOut)
          _ActionRow(
            icon: Icons.flag_outlined,
            label: context.l10n.report,
            destructive: true,
            onTap: () {
              Navigator.of(sheetCtx).pop();
              onAction(MessageAction.report);
            },
          ),
      ];

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: kMessageActionSheetMaxWidth,
                maxHeight: MediaQuery.sizeOf(sheetCtx).height * 0.75,
              ),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
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
                        if (onReact != null) ...[
                          _ReactionPicker(onReact: onReact),
                          const Divider(height: 1),
                        ],
                        _OriginalMessage(originalText: message.originalText),
                        const Divider(height: 1),
                        ...rows,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _ReactionPicker extends StatefulWidget {
  const _ReactionPicker({required this.onReact});

  final void Function(String emoji) onReact;

  @override
  State<_ReactionPicker> createState() => _ReactionPickerState();
}

class _ReactionPickerState extends State<_ReactionPicker> {
  bool _expanded = false;

  void _pick(String emoji) {
    Navigator.of(context).pop();
    widget.onReact(emoji);
  }

  @override
  Widget build(BuildContext context) {
    final reactions = _expanded
        ? [...kQuickMessageReactions, ...kMoreMessageReactions]
        : kQuickMessageReactions;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final emoji in reactions)
            _ReactionButton(emoji: emoji, onTap: () => _pick(emoji)),
          _MoreReactionButton(onTap: () => setState(() => _expanded = true)),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({required this.emoji, required this.onTap});

  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 24, height: 1)),
        ),
      ),
    );
  }
}

class _MoreReactionButton extends StatelessWidget {
  const _MoreReactionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('more-reactions'),
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: BlabColors.divider),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, size: 20, color: BlabColors.textPrimary),
      ),
    );
  }
}

class _OriginalMessage extends StatelessWidget {
  const _OriginalMessage({required this.originalText});

  final String originalText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('original-message'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.visibility_outlined,
              size: 24,
              color: BlabColors.textPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.viewOriginal,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: BlabColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  originalText,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.4,
                    color: BlabColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
