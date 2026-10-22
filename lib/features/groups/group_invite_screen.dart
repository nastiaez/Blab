import '../../shared/widgets/surfaces/blab_confirmation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
export 'group_invite_friends_screen.dart' show GroupInviteScreen;
import '../../l10n/l10n.dart';
import '../../shared/data/app_channel.dart';
import '../../shared/services/chat_service.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/widgets/navigation/blab_app_bar.dart';
import '../../shared/widgets/blab_avatar.dart';
import 'package:flutter/services.dart';
import '../invite/invite_share_service.dart';
import '../invite/invite_continuation.dart';
import '../invite/invite_link_panel.dart';
import '../invite/request_decision_footer.dart';
import 'pending_group_invitations.dart';
import '../onboarding/state/onboarding_destination_state.dart';

/// Owner/member share surface for an already-created BLA-14 group.
class GroupInviteLinkScreen extends ConsumerStatefulWidget {
  const GroupInviteLinkScreen({
    super.key,
    required this.chatId,
    required this.initialToken,
    this.groupName,
  });

  final String chatId;
  final String? initialToken;
  final String? groupName;

  @override
  ConsumerState<GroupInviteLinkScreen> createState() =>
      _GroupInviteLinkScreenState();
}

class _GroupInviteLinkScreenState extends ConsumerState<GroupInviteLinkScreen> {
  late Future<InviteToken> _token = _loadToken();
  bool _sharing = false;
  bool _regenerating = false;
  bool _shareFailed = false;

  Future<void> _confirmRegenerate() async {
    if (_regenerating) return;
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
        content: Text(context.l10n.groupReplaceLinkBody),
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
    if (confirmed == true && mounted) await _regenerate();
  }

  Future<void> _regenerate() async {
    if (_regenerating) return;
    setState(() => _regenerating = true);
    try {
      final token = await ref
          .read(chatServiceProvider)
          .replaceGroupInvite(widget.chatId);
      if (mounted) setState(() => _token = Future.value(token));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.couldNotUpdateGroup)),
        );
      }
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  Future<InviteToken> _loadToken() async {
    return ref.read(chatServiceProvider).createGroupInvite(widget.chatId);
  }

  Future<void> _share(InviteToken token) async {
    if (_sharing) return;
    setState(() {
      _sharing = true;
      _shareFailed = false;
    });
    try {
      await shareInviteText(AppChannel.inviteUrl(token.token));
    } catch (_) {
      if (mounted) setState(() => _shareFailed = true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BlabColors.chatCanvas,
    appBar: BlabAppBar(
      title: Text(
        context.l10n.groupInviteLinkTitle,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: BlabColors.warmInk,
        ),
      ),
      actions: [
        if (ref
                .watch(chatListProvider)
                .value
                ?.any(
                  (c) =>
                      c.id == widget.chatId &&
                      c.ownerId == ref.watch(currentUserIdProvider),
                ) ??
            false)
          PopupMenuButton<String>(
            tooltip: context.l10n.chatMenu,
            onSelected: (_) => _confirmRegenerate(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'replace',
                key: const ValueKey('regenerate-group-invite'),
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
      backgroundColor: BlabColors.chatCanvas,
    ),
    body: FutureBuilder<InviteToken>(
      future: _token,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _token = _loadToken()),
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.retry),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final link = AppChannel.inviteUrl(snapshot.data!.token);
        final groupName =
            widget.groupName ??
            ref
                .watch(chatListProvider)
                .value
                ?.where((chat) => chat.id == widget.chatId)
                .firstOrNull
                ?.partnerName;
        return InviteLinkPanel(
          title: groupName ?? context.l10n.groupInvitation,
          link: link,
          loading: _regenerating,
          sharing: _sharing,
          onCopy: _regenerating || _sharing
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: link));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(context.l10n.copied)));
                },
          onShare: _sharing || _regenerating
              ? null
              : () => _share(snapshot.data!),
          recovery: _shareFailed
              ? Text(
                  context.l10n.couldNotOpenSharing,
                  style: const TextStyle(color: BlabColors.error, fontSize: 13),
                )
              : null,
        );
      },
    ),
  );
}

/// Recipient’s native join screen. It never joins until the explicit action.
class GroupJoinScreen extends ConsumerStatefulWidget {
  const GroupJoinScreen({super.key, required this.token});
  final String token;

  @override
  ConsumerState<GroupJoinScreen> createState() => _GroupJoinScreenState();
}

class _GroupJoinScreenState extends ConsumerState<GroupJoinScreen> {
  late final Future<GroupInviteMetadata?> _metadata = _load();
  bool _joining = false;
  String? _error;

  Future<GroupInviteMetadata?> _load() async {
    final service = ref.read(chatServiceProvider);
    final metadata = await service.getGroupInvite(widget.token);
    if (metadata != null && !metadata.isMember) {
      try {
        await service.viewGroupInvitation(widget.token);
        if (mounted) ref.invalidate(pendingGroupInvitationsProvider);
      } catch (_) {
        /* Viewing must not imply acceptance, even offline. */
      }
    }
    return metadata;
  }

  Future<void> _reject() async {
    if (_joining) return;
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      await ref.read(chatServiceProvider).rejectGroupInvitation(widget.token);
      ref.invalidate(pendingGroupInvitationsProvider);
      if (mounted) context.go('/chats');
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.couldNotRejectGroupInvite);
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _join(GroupInviteMetadata metadata) async {
    if (_joining) return;
    if (metadata.isMember) {
      context.go('/chat/${metadata.chatId}');
      return;
    }
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      final joined = await ref
          .read(chatServiceProvider)
          .joinGroup(widget.token);
      ref.invalidate(chatListProvider);
      ref.invalidate(pendingGroupInvitationsProvider);
      await clearPendingInvite(matchingToken: widget.token);
      ref.invalidate(onboardingDestinationProvider);
      if (mounted) {
        context.go('/chat/${joined.chatId}');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().contains('group_full')
              ? context.l10n.groupFull
              : error.toString().contains('fresh_group_invitation_required')
              ? context.l10n.askFriendForNewLink
              : context.l10n.couldNotJoinGroup,
        );
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BlabColors.chatCanvas,
    appBar: BlabAppBar(
      backgroundColor: BlabColors.chatSurface,
      leading: BackButton(onPressed: () => context.go('/chats')),
      title: FutureBuilder<GroupInviteMetadata?>(
        future: _metadata,
        builder: (context, snapshot) {
          final name = snapshot.data?.groupName;
          if (name == null) return Text(context.l10n.groupInvitation);
          return Row(
            children: [
              BlabAvatar(name: name, size: 36, fontSize: 12),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
    body: FutureBuilder<GroupInviteMetadata?>(
      future: _metadata,
      builder: (context, snapshot) {
        if (snapshot.hasError || (snapshot.hasData && snapshot.data == null)) {
          return Center(child: Text(context.l10n.groupInvitationUnavailable));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final metadata = snapshot.data!;
        final unavailable = metadata.status != 'valid' && !metadata.isMember;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: BlabColors.error),
              ),
            ],
            const Spacer(),
            RequestDecisionFooter(
              message: context.l10n.joinToChatInGroup(metadata.groupName),
              primaryLabel: metadata.isMember
                  ? context.l10n.openChat
                  : unavailable && metadata.status == 'full'
                  ? context.l10n.groupFull
                  : context.l10n.joinAction,
              secondaryLabel: context.l10n.rejectAction,
              onPrimary: unavailable || _joining ? null : () => _join(metadata),
              onSecondary: _joining ? null : _reject,
            ),
          ],
        );
      },
    ),
  );
}
