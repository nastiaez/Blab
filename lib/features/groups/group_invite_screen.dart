import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
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
import '../invite/invite_link_card.dart';
import '../invite/request_decision_footer.dart';
import 'pending_group_invitations.dart';
import '../onboarding/state/onboarding_destination_state.dart';

/// Owner/member share surface for an already-created BLA-14 group.
class GroupInviteScreen extends ConsumerStatefulWidget {
  const GroupInviteScreen({
    super.key,
    required this.chatId,
    required this.initialToken,
    this.groupName,
  });

  final String chatId;
  final String? initialToken;
  final String? groupName;

  @override
  ConsumerState<GroupInviteScreen> createState() => _GroupInviteScreenState();
}

class _GroupInviteScreenState extends ConsumerState<GroupInviteScreen> {
  late Future<InviteToken> _token = _loadToken();
  bool _sharing = false;
  bool _regenerating = false;

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
    final existing = widget.initialToken;
    if (existing != null && existing.isNotEmpty) return InviteToken(existing);
    return ref.read(chatServiceProvider).createGroupInvite(widget.chatId);
  }

  Future<void> _share(InviteToken token) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      await shareInviteText(AppChannel.inviteUrl(token.token));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: BlabColors.chatCanvas,
    appBar: BlabAppBar(
      title: Text(
        context.l10n.inviteFriends,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: BlabColors.warmInk,
        ),
      ),
      backgroundColor: BlabColors.chatCanvas,
    ),
    body: FutureBuilder<InviteToken>(
      future: _token,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(context.l10n.couldNotOpenGroupInvite));
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
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InviteLinkCard(
                title: context.l10n.groupInvitation,
                link: link.replaceFirst('https://', ''),
                loading: _regenerating,
                onCopy: () async {
                  if (_regenerating) return;
                  await Clipboard.setData(ClipboardData(text: link));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(context.l10n.copied)));
                },
              ),
              const SizedBox(height: 16),
              if (ref
                      .watch(chatListProvider)
                      .asData
                      ?.value
                      .any(
                        (chat) =>
                            chat.id == widget.chatId &&
                            chat.ownerId == ref.watch(currentUserIdProvider),
                      ) ??
                  false)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    key: const ValueKey('regenerate-group-invite'),
                    onPressed: _regenerating ? null : _regenerate,
                    child: Text(context.l10n.regenerateInvite),
                  ),
                ),
              Text(
                groupName == null
                    ? ''
                    : context.l10n.anyoneCanJoinGroup(groupName),
                style: const TextStyle(
                  color: BlabColors.warmMuted,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  key: const ValueKey('share-group-invite-button'),
                  onPressed: _sharing || _regenerating
                      ? null
                      : () => _share(snapshot.data!),
                  child: Text(context.l10n.sendInvite),
                ),
              ),
            ],
          ),
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
