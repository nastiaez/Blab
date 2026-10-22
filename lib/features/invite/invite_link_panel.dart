import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../l10n/l10n.dart';

/// Shared Paper V15 sender contract; Material owns all activation/semantics.
class InviteLinkPanel extends StatelessWidget {
  const InviteLinkPanel({
    super.key,
    required this.title,
    required this.link,
    required this.onCopy,
    required this.onShare,
    this.loading = false,
    this.sharing = false,
    this.recovery,
  });
  final String title;
  final String? link;
  final VoidCallback? onCopy, onShare;
  final bool loading, sharing;
  final Widget? recovery;

  @override
  Widget build(BuildContext context) {
    final display = link?.replaceFirst('https://', '');
    final slash = display?.lastIndexOf('/') ?? -1;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              height: 32 / 24,
              fontWeight: FontWeight.w700,
              color: BlabColors.warmInk,
            ),
          ),
          const SizedBox(height: 40),
          Material(
            color: BlabColors.chatSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: BlabColors.chatDivider),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: Text(
                    loading
                        ? context.l10n.creatingLink
                        : display == null
                        ? context.l10n.inviteLinkUnavailable
                        : slash < 0
                        ? display
                        : '${display.substring(0, slash + 1)}\n${display.substring(slash + 1)}',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 22 / 14,
                      color: BlabColors.textMuted,
                    ),
                  ),
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: BlabColors.chatDivider,
                ),
                TextButton.icon(
                  key: const ValueKey('copy-invite-link'),
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_outlined, size: 20),
                  label: Text(context.l10n.copyLink),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    foregroundColor: BlabColors.warmInk,
                    shape: const RoundedRectangleBorder(),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('share-invite-link'),
            onPressed: onShare,
            icon: sharing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined, size: 20),
            label: Text(
              sharing
                  ? context.l10n.openingShareSheet
                  : context.l10n.inviteShareLink,
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              backgroundColor: BlabColors.brand,
              foregroundColor: BlabColors.warmInk,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (recovery != null) ...[const SizedBox(height: 12), recovery!],
        ],
      ),
    );
  }
}
