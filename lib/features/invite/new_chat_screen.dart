import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'invite_share_service.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/data/invite_host.dart';
import 'prepared_invite_state.dart';
import '../../shared/state/connectivity_state.dart';
import '../../shared/widgets/offline_banner.dart';
import 'invite_error_actions.dart';

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
      final link = 'https://$kInviteHost/i/$token';
      final exposed = await shareInviteText(
        context.l10n.inviteShareMessage(link),
      );
      // A link is never invalidated by sharing. Prepare another one in the
      // background for the next invite while keeping this page in place.
      if (mounted && exposed) {
        unawaited(ref.read(preparedInviteProvider.notifier).consume());
      }
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
    final link = invite.token == null ? null : '$kInviteHost/i/${invite.token}';
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
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F2),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.l10n.inviteFriend,
          style: const TextStyle(
            color: Color(0xFF46281C),
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
                  _InviteCard(link: link, loading: invite.loading),
                  if (!invite.failed)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        context.l10n.onePersonInvite,
                        style: const TextStyle(
                          color: Color(0xFF917869),
                          fontSize: 13,
                        ),
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
                            color: Color(0xFF917869),
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
                          color: Color(0xFF917869),
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
                          backgroundColor: const Color(0xFFF88C5A),
                          disabledBackgroundColor: BlabColors.disabledSurface,
                          foregroundColor: const Color(0xFF46281C),
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

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.link, required this.loading});

  final String? link;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('invite-card'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9DED5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.inviteCardTitle,
            style: const TextStyle(
              color: Color(0xFF46281C),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            loading
                ? context.l10n.creatingLink
                : link ?? context.l10n.inviteLinkUnavailable,
            style: const TextStyle(color: Color(0xFF917869), fontSize: 15),
          ),
        ],
      ),
    );
  }
}
