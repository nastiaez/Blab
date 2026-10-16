import '../../shared/widgets/surfaces/blab_section_label.dart';
import '../../shared/widgets/settings/blab_icon_label_row.dart';
import '../../shared/widgets/surfaces/blab_section_card.dart';
import '../../shared/widgets/blab_avatar.dart';
import '../../shared/widgets/navigation/blab_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_messenger.dart';
import '../../app/telegram_route.dart';
import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/chat.dart';
import '../../shared/state/chat_list_state.dart';
import 'widgets/block_confirmation_dialog.dart';
import 'widgets/chat_lifecycle_dialog.dart';
import 'widgets/partner_report_dialog.dart';

Future<void> showPartnerProfilePage(
  BuildContext context, {
  required Chat chat,
}) {
  return Navigator.of(
    context,
  ).push<void>(telegramRoute<void>(PartnerProfilePage(chat: chat)));
}

class PartnerProfilePage extends ConsumerStatefulWidget {
  const PartnerProfilePage({super.key, required this.chat});

  final Chat chat;

  @override
  ConsumerState<PartnerProfilePage> createState() => _PartnerProfilePageState();
}

class _PartnerProfilePageState extends ConsumerState<PartnerProfilePage> {
  bool? _blockedOverride;
  bool _leaving = false;
  bool _left = false;

  Chat get chat => widget.chat;

  Future<void> _report() async {
    final result = await showPartnerReportDialog(
      context,
      personName: chat.partnerName,
      onSubmit: _submitPartnerReport,
    );
    if (result == null || !mounted) return;

    if (result.blockSucceeded) {
      setState(() => _blockedOverride = true);
      ref.invalidate(blockedUserIdsProvider);
    }

    if (result.reportSucceeded &&
        (!result.blockRequested || result.blockSucceeded)) {
      showAppSuccessSnack(context.l10n.reportSubmitted);
      return;
    }
    if (result.reportSucceeded) {
      showAppSnack(
        context.l10n.reportSucceededBlockFailed,
        action: SnackBarAction(
          label: context.l10n.retry,
          onPressed: _retryBlock,
        ),
      );
      return;
    }
    if (result.blockSucceeded) {
      showAppSnack(
        context.l10n.blockSucceededReportFailed(chat.partnerName),
        action: SnackBarAction(
          label: context.l10n.retry,
          onPressed: _retryReport,
        ),
      );
    }
  }

  Future<PartnerReportResult> _submitPartnerReport({
    required bool block,
  }) async {
    var reportSucceeded = false;
    var blockSucceeded = false;

    Future<void> submitReport() async {
      try {
        await ref
            .read(chatServiceProvider)
            .reportContent(
              reason: 'spam',
              reportedUserId: chat.partnerId,
              chatId: chat.id,
            );
        reportSucceeded = true;
      } catch (_) {}
    }

    Future<void> submitBlock() async {
      try {
        await ref.read(chatServiceProvider).blockUser(chat.partnerId!);
        blockSucceeded = true;
      } catch (_) {}
    }

    await Future.wait([submitReport(), if (block) submitBlock()]);
    return PartnerReportResult(
      reportSucceeded: reportSucceeded,
      blockRequested: block,
      blockSucceeded: blockSucceeded,
    );
  }

  Future<void> _retryReport() async {
    try {
      await ref
          .read(chatServiceProvider)
          .reportContent(
            reason: 'spam',
            reportedUserId: chat.partnerId,
            chatId: chat.id,
          );
      if (!mounted) return;
      showAppSuccessSnack(context.l10n.reportSubmitted);
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context.l10n.couldNotReport,
        action: SnackBarAction(
          label: context.l10n.retry,
          onPressed: _retryReport,
        ),
      );
    }
  }

  Future<void> _retryBlock() async {
    try {
      await ref.read(chatServiceProvider).blockUser(chat.partnerId!);
      if (!mounted) return;
      setState(() => _blockedOverride = true);
      ref.invalidate(blockedUserIdsProvider);
      showAppSuccessSnack(context.l10n.personBlocked(chat.partnerName));
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context.l10n.couldNotBlock,
        action: SnackBarAction(
          label: context.l10n.retry,
          onPressed: _retryBlock,
        ),
      );
    }
  }

  Future<void> _block() async {
    final confirmed = await showBlockConfirmation(
      context,
      personName: chat.partnerName,
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(chatServiceProvider).blockUser(chat.partnerId!);
      if (!mounted) return;
      setState(() => _blockedOverride = true);
      ref.invalidate(blockedUserIdsProvider);
    } catch (_) {
      if (mounted) showAppSnack(context.l10n.couldNotBlock);
    }
  }

  Future<void> _leave() async {
    if (_leaving || _left || chat.isLeft) return;
    final confirmed = await showChatLifecycleConfirmation(
      context,
      title: context.l10n.leaveChatQuestion,
      message: context.l10n.leaveChatConfirmation,
      confirmLabel: context.l10n.leaveChat,
    );
    if (!confirmed || !mounted) return;
    setState(() => _leaving = true);
    try {
      await ref.read(chatListProvider.notifier).leaveChat(chat.id);
      if (!mounted) return;
      setState(() => _left = true);
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) showAppSnack(context.l10n.couldNotLeaveChat);
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  Future<void> _unblock() async {
    try {
      await ref.read(chatServiceProvider).unblockUser(chat.partnerId!);
      if (!mounted) return;
      setState(() => _blockedOverride = false);
      ref.invalidate(blockedUserIdsProvider);
      showAppSuccessSnack(context.l10n.personUnblocked(chat.partnerName));
    } catch (_) {
      if (mounted) showAppSnack(context.l10n.couldNotUnblock);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blockedIds =
        ref.watch(blockedUserIdsProvider).value ?? const <String>{};
    final isBlocked =
        _blockedOverride ?? blockedIds.contains(widget.chat.partnerId);

    return Scaffold(
      backgroundColor: BlabColors.chatCanvas,
      appBar: BlabAppBar(
        backgroundColor: BlabColors.chatSurface,
        foregroundColor: BlabColors.warmInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            _IdentityHeader(chat: chat),
            const SizedBox(height: 28),
            _ProfileSection(
              title: context.l10n.languages,
              children: [
                _LanguageRow(
                  flag: chat.partnerNativeLanguage.flag,
                  label: context.l10n.speaksNatively(
                    localizedLanguageName(
                      context.l10n,
                      chat.partnerNativeLanguage.code,
                    ),
                  ),
                ),
                _LanguageRow(
                  flag: chat.partnerLearningLanguage.flag,
                  label: context.l10n.learningWithYou(
                    localizedLanguageName(
                      context.l10n,
                      chat.partnerLearningLanguage.code,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ProfileSection(
              title: context.l10n.chat,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Text(
                    _startedAgo(context, chat.startedAt ?? chat.timestamp),
                    style: const TextStyle(
                      color: BlabColors.warmInk,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            if (chat.partnerId != null) ...[
              const SizedBox(height: 16),
              _ProfileSection(
                title: context.l10n.safety,
                children: [
                  BlabIconLabelRow.partnerSafety(
                    key: const Key('partner-report-action'),
                    icon: Icons.flag_outlined,
                    label: context.l10n.reportPerson(chat.partnerName),
                    onTap: _report,
                  ),
                  BlabIconLabelRow.partnerSafety(
                    key: const Key('partner-block-action'),
                    icon: isBlocked ? Icons.lock_open_outlined : Icons.block,
                    label: isBlocked
                        ? context.l10n.unblockPerson(chat.partnerName)
                        : context.l10n.blockPerson(chat.partnerName),
                    destructive: !isBlocked,
                    onTap: isBlocked ? _unblock : _block,
                  ),
                  BlabIconLabelRow.partnerSafety(
                    key: const Key('partner-leave-action'),
                    icon: Icons.logout,
                    label: _left || chat.isLeft
                        ? context.l10n.leftChat
                        : context.l10n.leaveChat,
                    destructive: true,
                    onTap: _leaving || _left || chat.isLeft ? null : _leave,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BlabAvatar(
          name: chat.partnerName,
          initials: chat.partnerInitial,
          size: 104,
          fontSize: 38,
          fontWeight: FontWeight.w700,
          shadows: null,
        ),
        const SizedBox(height: 16),
        Text(
          chat.partnerName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: BlabColors.warmInk,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${context.l10n.learningLanguage}: '
          '${localizedLanguageName(context.l10n, chat.partnerLearningLanguage.code)} '
          '${chat.partnerLearningLanguage.flag}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: BlabColors.warmMuted),
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: BlabSectionLabel.partner(title),
        ),
        BlabSectionCard.flush(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              children[index],
              if (index < children.length - 1)
                const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: BlabColors.chatDivider,
                ),
            ],
          ],
        ),
      ],
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.flag, required this.label});

  final String flag;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: BlabColors.warmInk, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

String _startedAgo(BuildContext context, DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return context.l10n.startedJustNow;
  if (diff.inHours < 1) {
    return context.l10n.startedMinutesAgo(diff.inMinutes);
  }
  if (diff.inDays < 1) return context.l10n.startedHoursAgo(diff.inHours);
  if (diff.inDays < 30) return context.l10n.startedDaysAgo(diff.inDays);
  return context.l10n.startedMonthsAgo((diff.inDays / 30).floor());
}
