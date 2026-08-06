import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../shared/models/chat.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/widgets/offline_banner.dart';
import '../chat/state/chat_state.dart';
import '../chat/widgets/photo_preview_sheet.dart';
import 'android_share_intent_service.dart';

class ShareImageScreen extends ConsumerWidget {
  const ShareImageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final image = ref.watch(pendingSharedImageProvider);
    final chatsAsync = ref.watch(visibleChatsProvider);
    if (image == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: BlabColors.textPrimary,
          title: const Text('Share photo'),
        ),
        body: const Center(
          child: Text(
            'No photo selected',
            style: TextStyle(color: BlabColors.textMuted),
          ),
        ),
      );
    }

    final chats = chatsAsync.value;
    if (chats == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
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
      image: image,
      chats: chats,
      onChatSelected: (chat) => _sendToChat(context, ref, image, chat),
      header: const OfflineBanner(),
    );
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
    required this.image,
    required this.chats,
    required this.onChatSelected,
    this.header,
  });

  final AndroidSharedImage image;
  final List<Chat> chats;
  final ValueChanged<Chat> onChatSelected;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: BlabColors.textPrimary,
        title: const Text(
          'Share photo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            ?header,
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  _SharedImageThumbnail(image: image),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Choose a chat',
                      style: TextStyle(
                        color: BlabColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade100),
            Expanded(
              child: chats.isEmpty
                  ? const Center(
                      child: Text(
                        'No chats yet',
                        style: TextStyle(color: BlabColors.textMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: chats.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.grey.shade100),
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        return _ShareChatRow(
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

class _SharedImageThumbnail extends StatelessWidget {
  const _SharedImageThumbnail({required this.image});

  final AndroidSharedImage image;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        key: const ValueKey('shared-image-thumbnail'),
        width: 56,
        height: 56,
        child: Image.memory(
          image.bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: BlabColors.phoneSurface,
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_outlined,
                color: BlabColors.textMuted,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ShareChatRow extends StatelessWidget {
  const _ShareChatRow({required this.chat, required this.onTap});

  final Chat chat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: BlabColors.avatarColorFor(chat.partnerName),
              child: Text(
                chat.partnerInitial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.partnerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BlabColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to choose',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: BlabColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: BlabColors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
