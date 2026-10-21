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
import 'invite_link_card.dart';

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

  @override
  Widget build(BuildContext context) {
    final online = ref.watch(isOnlineProvider);
    final invite = ref.watch(preparedInviteProvider);
    final link = invite.token == null
        ? null
        : AppChannel.inviteUrl(invite.token!).replaceFirst('https://', '');
    final createFailure = splitInviteRecoveryMessage(
      context.l10n.couldNotCreateInvite,
      context.l10n.retry,
    );
    final enabled =
        online &&
        !invite.loading &&
        !_sharing &&
        !invite.failed &&
        link != null;
    return Scaffold(
      backgroundColor: BlabColors.chatCanvas,
      appBar: BlabAppBar(
        backgroundColor: BlabColors.chatCanvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.l10n.inviteFriend,
          style: const TextStyle(
            color: BlabColors.warmInk,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  InviteLinkCard(link: link, loading: invite.loading),
                  if (!invite.failed)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        context.l10n.reusableInviteHelp,
                        style: const TextStyle(
                          color: BlabColors.warmMuted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  if (invite.token != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: online && !invite.loading && !_sharing
                            ? () => ref
                                  .read(preparedInviteProvider.notifier)
                                  .regenerate()
                            : null,
                        child: Text(context.l10n.regenerateInvite),
                      ),
                    ),
                  if (online && invite.failed) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      key: const ValueKey('invite-create-recovery'),
                      spacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          createFailure.message,
                          style: const TextStyle(
                            color: BlabColors.warmMuted,
                            fontSize: 13,
                          ),
                        ),
                        InviteTextAction(
                          label: createFailure.action,
                          edgeAligned: true,
                          onPressed: () => ref
                              .read(preparedInviteProvider.notifier)
                              .prepare(),
                        ),
                      ],
                    ),
                  ],
                  if (_shareFailed)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        context.l10n.couldNotOpenSharing,
                        style: const TextStyle(
                          color: BlabColors.error,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (!invite.failed)
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: BlabColors.brand,
                          disabledBackgroundColor: BlabColors.disabledSurface,
                          foregroundColor: BlabColors.warmInk,
                          disabledForegroundColor: BlabColors.disabledOnSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: enabled ? _sendInvite : null,
                        child: Text(
                          _sharing
                              ? context.l10n.openingShareSheet
                              : context.l10n.sendInvite,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
