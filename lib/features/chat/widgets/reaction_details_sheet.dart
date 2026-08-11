import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/models/message_reaction.dart';

/// WhatsApp-style "who reacted with what" sheet, opened by tapping an
/// existing reaction badge. Blab chats are 1:1, so each summary's count
/// maps to at most two people: the viewer (if [MessageReactionSummary.
/// reactedByMe]) and the partner (any remaining count on that emoji).
/// Tapping the viewer's own row removes their reaction — no picker
/// re-entry needed since removal is the only self-action here.
Future<void> showReactionDetailsSheet(
  BuildContext context, {
  required List<MessageReactionSummary> reactions,
  required String partnerName,
  required void Function(String emoji) onChangeReaction,
}) {
  final rows = <_Reactor>[];
  for (final reaction in reactions) {
    if (reaction.reactedByMe) {
      rows.add(
        _Reactor(name: context.l10n.you, emoji: reaction.emoji, isMe: true),
      );
    }
    final othersOnThisEmoji = reaction.count - (reaction.reactedByMe ? 1 : 0);
    if (othersOnThisEmoji > 0) {
      rows.add(_Reactor(name: partnerName, emoji: reaction.emoji));
    }
  }
  final total = reactions.fold<int>(0, (sum, r) => sum + r.count);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
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
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4DCCC),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                sheetCtx.l10n.reactionsCount(total),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: BlabColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              for (final reactor in rows)
                _ReactorRow(
                  reactor: reactor,
                  onTapToRemove: reactor.isMe
                      ? () {
                          Navigator.of(sheetCtx).pop();
                          onChangeReaction(reactor.emoji);
                        }
                      : null,
                ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      );
    },
  );
}

class _Reactor {
  const _Reactor({required this.name, required this.emoji, this.isMe = false});

  final String name;
  final String emoji;
  final bool isMe;
}

class _ReactorRow extends StatelessWidget {
  const _ReactorRow({required this.reactor, this.onTapToRemove});

  final _Reactor reactor;
  final VoidCallback? onTapToRemove;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: BlabColors.brand.withValues(alpha: 0.15),
            child: Text(
              reactor.name.isNotEmpty ? reactor.name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: BlabColors.brand,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reactor.name,
                  style: const TextStyle(
                    fontSize: 15,
                    color: BlabColors.textPrimary,
                  ),
                ),
                if (onTapToRemove != null)
                  Text(
                    context.l10n.tapToRemove,
                    style: const TextStyle(
                      fontSize: 12,
                      color: BlabColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          Text(reactor.emoji, style: const TextStyle(fontSize: 22)),
        ],
      ),
    );
    if (onTapToRemove == null) return row;
    return InkWell(
      key: const ValueKey('reaction-details-remove-mine'),
      onTap: onTapToRemove,
      child: row,
    );
  }
}
