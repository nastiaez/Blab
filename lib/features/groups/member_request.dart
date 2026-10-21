import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/app_messenger.dart';
import '../../l10n/l10n.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/state/chat_list_state.dart';
import '../chat/widgets/block_confirmation_dialog.dart';
import '../invite/request_decision_footer.dart';

final memberRequestProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, chatId) {
      ref.watch(currentUserIdProvider);
      return ref.watch(chatServiceProvider).watchMemberRequest(chatId);
    });

class MemberRequestFooter extends ConsumerStatefulWidget {
  const MemberRequestFooter({
    super.key,
    required this.chatId,
    required this.name,
    required this.incoming,
  });
  final String chatId, name;
  final bool incoming;
  @override
  ConsumerState<MemberRequestFooter> createState() =>
      _MemberRequestFooterState();
}

class _MemberRequestFooterState extends ConsumerState<MemberRequestFooter> {
  bool _busy = false;
  Future<void> _act(bool block) async {
    if (_busy) return;
    if (block &&
        !await showBlockConfirmation(context, personName: widget.name)) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(chatServiceProvider);
      if (block) {
        await service.blockMemberRequest(widget.chatId);
        ref.invalidate(blockedUserIdsProvider);
        ref.invalidate(chatListProvider);
        if (mounted) context.go('/chats');
      } else {
        await service.acceptMemberRequest(widget.chatId);
        ref.invalidate(memberRequestProvider(widget.chatId));
      }
    } catch (_) {
      if (mounted) showAppSnack(context.l10n.couldNotUpdateGroup);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.incoming
      ? RequestDecisionFooter(
          message: context.l10n.acceptToReply(widget.name),
          primaryLabel: context.l10n.acceptRequest,
          secondaryLabel: context.l10n.block,
          onPrimary: _busy ? null : () => _act(false),
          onSecondary: _busy ? null : () => _act(true),
        )
      : SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              context.l10n.waitingForAcceptance,
              textAlign: TextAlign.center,
            ),
          ),
        );
}
