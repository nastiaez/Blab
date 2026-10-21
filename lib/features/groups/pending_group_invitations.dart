import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/services/chat_service.dart';
import '../../shared/models/chat.dart';
import '../../shared/data/languages.dart';
import '../chats/widgets/chat_list_tile.dart';

final pendingGroupInvitationsProvider =
    FutureProvider<List<PendingGroupInvitation>>((ref) async {
      if (ref.watch(currentUserIdProvider) == null) return [];
      return ref.watch(chatServiceProvider).fetchPendingGroupInvitations();
    });

class PendingGroupInvitationTile extends StatelessWidget {
  const PendingGroupInvitationTile({super.key, required this.invitation});
  final PendingGroupInvitation invitation;
  @override
  Widget build(BuildContext context) {
    final language = kBlabLanguages.first;
    return ChatListTile(
      invitation: true,
      chat: Chat(
        id: invitation.chatId,
        partnerName: invitation.groupName,
        partnerInitial: invitation.groupName.isEmpty
            ? '?'
            : invitation.groupName[0],
        learningLanguage: language,
        mode: ChatMode.normal,
        partnerNativeLanguage: language,
        partnerLearningLanguage: language,
        lastMessage: '',
        lastMessageTranslation: '',
        timestamp: invitation.createdAt,
        unreadCount: invitation.unread ? 1 : 0,
        kind: ChatKind.group,
      ),
      onTap: () => context.push(
        '/group-invite/${Uri.encodeComponent(invitation.token)}',
      ),
    );
  }
}
