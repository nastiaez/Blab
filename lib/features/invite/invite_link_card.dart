import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';

/// Shared invitation presentation; the owning flow supplies its title/actions.
class InviteLinkCard extends StatelessWidget {
  const InviteLinkCard({
    super.key,
    required this.link,
    required this.loading,
    this.title,
    this.onCopy,
  });
  final String? link;
  final bool loading;
  final String? title;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      key: const ValueKey('invite-card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BlabColors.chatSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BlabColors.chatDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title ?? context.l10n.inviteCardTitle,
            style: const TextStyle(
              color: BlabColors.warmInk,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            loading
                ? context.l10n.creatingLink
                : link ?? context.l10n.inviteLinkUnavailable,
            style: const TextStyle(color: BlabColors.warmMuted, fontSize: 15),
          ),
        ],
      ),
    );
    if (onCopy == null || loading || link == null) return card;
    return Semantics(
      button: true,
      label: context.l10n.copyLink,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('copy-invite-link'),
          onTap: onCopy,
          borderRadius: BorderRadius.circular(16),
          child: card,
        ),
      ),
    );
  }
}
