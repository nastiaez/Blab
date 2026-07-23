import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_messenger.dart';
import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/models/chat.dart';
import '../../../shared/state/chat_list_state.dart';
import 'report_sheet.dart';

/// Result of the partner profile sheet. `blocked` tells the caller to leave
/// the chat (the partner is now hidden from the chat list). Step 3.6a.
enum PartnerProfileResult { blocked }

/// Bottom sheet shown when the user taps the partner avatar / name in the
/// chat header. Shows who the partner is + Report / Block safety actions.
Future<PartnerProfileResult?> showPartnerProfileSheet(
  BuildContext context, {
  required Chat chat,
}) {
  return showModalBottomSheet<PartnerProfileResult>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _Body(chat: chat),
  );
}

class _Body extends StatelessWidget {
  const _Body({required this.chat});
  final Chat chat;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: BlabColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Avatar
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: BlabColors.avatarColorFor(chat.partnerName),
              ),
              alignment: Alignment.center,
              child: Text(
                chat.partnerInitial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 36,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              chat.partnerName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: BlabColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${context.l10n.learningLanguage}: ${chat.partnerLearningLanguage.name} ${chat.partnerLearningLanguage.flag}',
              style: const TextStyle(fontSize: 13, color: BlabColors.textMuted),
            ),
            const SizedBox(height: 28),
            _Section(
              title: context.l10n.languages,
              children: [
                _LangRow(
                  flag: chat.partnerNativeLanguage.flag,
                  text: context.l10n.speaksNatively(
                    chat.partnerNativeLanguage.name,
                  ),
                  emphasis: '',
                  trailing: '',
                ),
                _LangRow(
                  flag: chat.partnerLearningLanguage.flag,
                  text: context.l10n.learningWithYou(
                    chat.partnerLearningLanguage.name,
                  ),
                  emphasis: '',
                  trailing: '',
                ),
              ],
            ),
            const SizedBox(height: 22),
            _Section(
              title: context.l10n.chat,
              children: [
                Text(
                  _startedAgo(context, chat.startedAt ?? chat.timestamp),
                  style: const TextStyle(
                    fontSize: 14,
                    color: BlabColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (chat.partnerId != null) ...[
              const SizedBox(height: 22),
              _SafetyActions(chat: chat),
            ],
          ],
        ),
      ),
    );
  }

  String _startedAgo(BuildContext context, DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return context.l10n.startedJustNow;
    if (diff.inHours < 1) {
      return context.l10n.startedMinutesAgo(diff.inMinutes);
    }
    if (diff.inDays < 1) return context.l10n.startedHoursAgo(diff.inHours);
    if (diff.inDays < 30) return context.l10n.startedDaysAgo(diff.inDays);
    final months = (diff.inDays / 30).floor();
    return context.l10n.startedMonthsAgo(months);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      // Full width so every section's content left-aligns consistently.
      // Without this, a section that only holds short text (e.g. "Chat")
      // shrink-wraps and gets centered by the sheet's centering Column.
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: BlabColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),
            ...children.expand((c) => [c, const SizedBox(height: 8)]).toList()
              ..removeLast(),
          ],
        ),
      ),
    );
  }
}

class _SafetyActions extends ConsumerWidget {
  const _SafetyActions({required this.chat});
  final Chat chat;

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    final success = context.l10n.thanksReport;
    final failure = context.l10n.couldNotReport;
    final reason = await showReportReasonSheet(
      context,
      title: context.l10n.reportPerson(chat.partnerName),
    );
    if (reason == null) return;
    try {
      await ref
          .read(chatServiceProvider)
          .reportContent(
            reason: reason.wire,
            reportedUserId: chat.partnerId,
            chatId: chat.id,
          );
      showAppSnack(success);
    } catch (_) {
      showAppSnack(failure);
    }
  }

  Future<void> _block(BuildContext context, WidgetRef ref) async {
    final success = context.l10n.personBlocked(chat.partnerName);
    final failure = context.l10n.couldNotBlock;
    try {
      await ref.read(chatServiceProvider).blockUser(chat.partnerId!);
      if (context.mounted) {
        Navigator.of(context).pop(PartnerProfileResult.blocked);
      }
      showAppSnack(success);
    } catch (_) {
      showAppSnack(failure);
    }
  }

  Future<void> _unblock(BuildContext context, WidgetRef ref) async {
    final success = context.l10n.personUnblocked(chat.partnerName);
    final failure = context.l10n.couldNotUnblock;
    try {
      await ref.read(chatServiceProvider).unblockUser(chat.partnerId!);
      showAppSnack(success);
    } catch (_) {
      showAppSnack(failure);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedUserIdsProvider).value ?? const <String>{};
    final isBlocked = blocked.contains(chat.partnerId);
    return _Section(
      title: context.l10n.safety,
      children: [
        _SafetyRow(
          icon: Icons.flag_outlined,
          label: context.l10n.reportPerson(chat.partnerName),
          onTap: () => _report(context, ref),
        ),
        _SafetyRow(
          icon: isBlocked ? Icons.lock_open_outlined : Icons.block,
          label: isBlocked
              ? context.l10n.unblockPerson(chat.partnerName)
              : context.l10n.blockPerson(chat.partnerName),
          destructive: !isBlocked,
          onTap: () =>
              isBlocked ? _unblock(context, ref) : _block(context, ref),
        ),
      ],
    );
  }
}

class _SafetyRow extends StatelessWidget {
  const _SafetyRow({
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
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

class _LangRow extends StatelessWidget {
  const _LangRow({
    required this.flag,
    required this.text,
    required this.emphasis,
    required this.trailing,
  });

  final String flag;
  final String text;
  final String emphasis;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(flag, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: text,
                  style: const TextStyle(
                    fontSize: 15,
                    color: BlabColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: emphasis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BlabColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: trailing,
                  style: const TextStyle(
                    fontSize: 15,
                    color: BlabColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
