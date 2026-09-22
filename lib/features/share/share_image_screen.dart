import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../shared/models/chat.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/widgets/offline_banner.dart';
import '../chat/state/chat_state.dart';
import '../chat/widgets/photo_preview_sheet.dart';
import '../chats/widgets/chat_list_tile.dart';
import 'android_share_intent_service.dart';

class ShareImageScreen extends ConsumerWidget {
  const ShareImageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(pendingSharedImageProvider);
    final chatsAsync = ref.watch(shareableChatsProvider);
    if (image == null) {
      return Scaffold(
        backgroundColor: BlabColors.appBackground,
        appBar: AppBar(
          backgroundColor: BlabColors.appBackground,
          elevation: 0,
          foregroundColor: BlabColors.warmInk,
          title: const Text(
            'Share photo',
            style: TextStyle(color: BlabColors.warmInk),
          ),
        ),
        body: const Center(
          child: Text(
            'No photo selected',
            style: TextStyle(color: BlabColors.warmMuted),
          ),
        ),
      );
    }

    final chats = chatsAsync.value;
    if (chats == null) {
      return const Scaffold(
        backgroundColor: BlabColors.appBackground,
        body: SafeArea(
          child: Column(
            children: [
              OfflineBanner(),
              Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      );
    }

    return ShareImageChatPicker(
      chats: chats,
      onChatSelected: (chat) => _sendToChat(context, ref, image, chat),
      onBack: () => _cancelShare(context, ref),
      header: const OfflineBanner(),
    );
  }

  Future<void> _cancelShare(BuildContext context, WidgetRef ref) async {
    ref.read(pendingSharedImageProvider.notifier).clear();
    if (context.canPop()) {
      context.pop();
      return;
    }
    await SystemNavigator.pop(animated: true);
  }

  Future<void> _sendToChat(
    BuildContext context,
    WidgetRef ref,
    AndroidSharedImage image,
    Chat chat,
  ) async {
    final caption = await showPhotoPreviewSheet(
      context,
      image.toPickedChatImage(),
      chat.partnerName,
    );
    if (caption == null || !context.mounted) return;
    try {
      await ref
          .read(chatMessagesProvider(chat.id).notifier)
          .addOutgoingPhoto(image.toPickedChatImage(), caption: caption);
      ref.read(pendingSharedImageProvider.notifier).clear();
      if (context.mounted) context.go('/chat/${chat.id}');
    } catch (_) {
      if (context.mounted) showAppSnack('Could not share photo. Try again.');
    }
  }
}

class ShareImageChatPicker extends StatelessWidget {
  const ShareImageChatPicker({
    super.key,
    required this.chats,
    required this.onChatSelected,
    required this.onBack,
    this.header,
  });

  final List<Chat> chats;
  final ValueChanged<Chat> onChatSelected;
  final VoidCallback onBack;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlabColors.chatCanvas,
      appBar: AppBar(
        backgroundColor: BlabColors.chatCanvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: BlabColors.textPrimary,
          onPressed: onBack,
        ),
        title: const Text(
          'Select chat',
          style: TextStyle(
            color: BlabColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            ?header,
            Expanded(
              child: chats.isEmpty
                  ? const Center(
                      child: Text(
                        'No chats yet',
                        style: TextStyle(color: BlabColors.warmMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: chats.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        indent: 76,
                        color: BlabColors.chatDivider,
                      ),
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        return ChatListTile(
                          chat: chat,
                          onTap: () => onChatSelected(chat),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
