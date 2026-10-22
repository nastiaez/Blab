import '../../shared/widgets/surfaces/blab_confirmation_dialog.dart';
import '../../shared/widgets/navigation/blab_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'invite_share_service.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/data/app_channel.dart';
import 'prepared_invite_state.dart';
import '../../shared/state/connectivity_state.dart';
import '../../shared/widgets/offline_banner.dart';
import 'invite_error_actions.dart';
import 'invite_link_panel.dart';
import 'package:flutter/services.dart';

/// A single-purpose invite screen. Links create a connection only; practice
/// language is chosen privately when the resulting chat is opened.
class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  bool _sharing = false;
  bool _shareFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialToken case final token?) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(preparedInviteProvider.notifier).useToken(token);
      });
    }
  }

  Future<void> _sendInvite() async {
    final token = ref.read(preparedInviteProvider).token;
    if (_sharing || token == null || !ref.read(isOnlineProvider)) return;
    setState(() {
      _sharing = true;
      _shareFailed = false;
    });
    try {
      final link = AppChannel.inviteUrl(token);
      await shareInviteText(context.l10n.inviteShareMessage(link));
    } catch (_) {
      if (mounted) setState(() => _shareFailed = true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _resetLink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BlabConfirmationDialog(
        scrollable: true,
        backgroundColor: BlabColors.chatSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
          side: BorderSide(color: BlabColors.chatDivider),
        ),
        title: Text(context.l10n.inviteResetTitle),
        content: Text(context.l10n.personalInviteResetBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: BlabColors.warmInk),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.inviteResetAction),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref.read(preparedInviteProvider.notifier).regenerate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(isOnlineProvider);
    final invite = ref.watch(preparedInviteProvider);
    final link = invite.token == null
        ? null
        : AppChannel.inviteUrl(invite.token!);
    final enabled =
        online &&
        !invite.loading &&
        !_sharing &&
        !invite.failed &&
        link != null;
    final failure = splitInviteRecoveryMessage(
      context.l10n.couldNotCreateInvite,
      context.l10n.retry,
    );
    return Scaffold(
      backgroundColor: BlabColors.chatCanvas,
      appBar: BlabAppBar(
        backgroundColor: BlabColors.chatCanvas,
        title: Text(
          context.l10n.inviteFriend,
          style: const TextStyle(
            color: BlabColors.warmInk,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: context.l10n.chatMenu,
            enabled: enabled,
            onSelected: (_) => _resetLink(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    const Icon(Icons.refresh, size: 20),
                    const SizedBox(width: 12),
                    Flexible(child: Text(context.l10n.inviteResetAction)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: InviteLinkPanel(
              title: context.l10n.inviteCardTitle,
              link: link,
              loading: invite.loading,
              sharing: _sharing,
              onShare: enabled ? _sendInvite : null,
              onCopy: enabled
                  ? () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.l10n.copied)),
                      );
                    }
                  : null,
              recovery: online && invite.failed
                  ? Wrap(
                      key: const ValueKey('invite-create-recovery'),
                      spacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          failure.message,
                          style: const TextStyle(
                            color: BlabColors.warmMuted,
                            fontSize: 13,
                          ),
                        ),
                        InviteTextAction(
                          label: failure.action,
                          edgeAligned: true,
                          onPressed: () => ref
                              .read(preparedInviteProvider.notifier)
                              .prepare(),
                        ),
                      ],
                    )
                  : _shareFailed
                  ? Text(
                      context.l10n.couldNotOpenSharing,
                      style: const TextStyle(
                        color: BlabColors.error,
                        fontSize: 13,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
