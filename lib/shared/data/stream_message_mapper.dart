import 'package:stream_chat/stream_chat.dart' as stream;

import '../models/message.dart';

/// US-013 / US-017: vendor data is adapted without replacing Blab's UI.
Message? messageFromStream(
  stream.Message source, {
  required String chatId,
  required String currentUserId,
  bool replyPreview = false,
}) {
  if (source.isError || source.isEphemeral || source.isSystem) return null;
  final deleted = source.deletedAt != null || source.isDeleted;
  if (deleted && !replyPreview) return null;
  if (source.user?.id == null || source.remoteCreatedAt == null) return null;
  final images = source.attachments.where((a) => a.type == 'image');
  final image = deleted ? null : images.firstOrNull;
  final metadata = image?.extraData ?? const <String, Object?>{};
  final quote = source.quotedMessage;
  return Message(
    id: source.id,
    chatId: chatId,
    isOutgoing: source.user!.id == currentUserId,
    originalText: deleted ? 'Deleted message' : source.text ?? '',
    translation: '',
    sentAt: source.remoteCreatedAt!.toLocal(),
    status: MessageStatus.delivered,
    type: image == null ? MessageType.text : MessageType.image,
    isEdited:
        !deleted &&
        (source.messageTextUpdatedAt != null ||
            source.extraData['blab_legacy_edited'] == true),
    languagesMatchedAtSend:
        source.extraData['blab_languages_matched_at_send'] == true,
    attachment: image == null
        ? null
        : MessageAttachment(
            id: metadata['blab_asset_id'] as String? ?? image.id,
            messageId: source.id,
            chatId: chatId,
            storageBucket:
                metadata['blab_storage_bucket'] as String? ?? 'stream',
            storagePath: metadata['blab_storage_path'] as String? ?? image.id,
            previewStoragePath:
                metadata['blab_preview_storage_path'] as String?,
            mimeType: image.mimeType ?? 'image/jpeg',
            byteSize: image.fileSize ?? 0,
            previewMimeType: metadata['blab_preview_mime_type'] as String?,
            previewByteSize: (metadata['blab_preview_file_size'] as num?)
                ?.toInt(),
            url: image.assetUrl ?? image.imageUrl,
            previewUrl: image.thumbUrl ?? image.imageUrl,
          ),
    // A quotation is a one-level preview, never a recursively nested thread.
    replyTo: quote == null || replyPreview
        ? null
        : messageFromStream(
            quote,
            chatId: chatId,
            currentUserId: currentUserId,
            replyPreview: true,
          ),
  );
}
