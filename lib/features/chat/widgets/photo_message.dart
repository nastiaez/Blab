part of '../chat_screen.dart';

class _CachedAttachmentImage {
  const _CachedAttachmentImage({required this.kind, required this.provider});

  final String kind;
  final ImageProvider<Object> provider;
}

ImageProvider<Object>? _attachmentImageProvider(MessageAttachment attachment) {
  final cached = _attachmentImageProviders[attachment.id];
  final bytes = attachment.localBytes;
  if (bytes != null && bytes.isNotEmpty) {
    if (cached?.kind == 'full:${bytes.length}') return cached!.provider;
    final provider = MemoryImage(Uint8List.fromList(bytes));
    _attachmentImageProviders[attachment.id] = _CachedAttachmentImage(
      kind: 'full:${bytes.length}',
      provider: provider,
    );
    return provider;
  }

  final previewBytes = attachment.previewBytes;
  if (previewBytes != null && previewBytes.isNotEmpty) {
    if (cached?.kind == 'preview:${previewBytes.length}') {
      return cached!.provider;
    }
    final provider = MemoryImage(Uint8List.fromList(previewBytes));
    _attachmentImageProviders[attachment.id] = _CachedAttachmentImage(
      kind: 'preview:${previewBytes.length}',
      provider: provider,
    );
    return provider;
  }

  final url = attachment.url;
  if (url != null && url.isNotEmpty) {
    // Reuse the provider while the signed URL is unchanged. If the URL is
    // refreshed, create one new provider; gaplessPlayback keeps the old
    // frame visible until the refreshed image is ready.
    if (cached?.kind == 'network:$url') return cached!.provider;
    final provider = NetworkImage(url);
    _attachmentImageProviders[attachment.id] = _CachedAttachmentImage(
      kind: 'network:$url',
      provider: provider,
    );
    return provider;
  }

  return cached?.provider;
}

class PhotoMessageView extends ConsumerWidget {
  const PhotoMessageView({
    super.key,
    required this.attachment,
    this.cornerRadius = 12,
  });

  final MessageAttachment attachment;
  final double cornerRadius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = _attachmentImageProvider(attachment);
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(cornerRadius),
      child: SizedBox(
        width: 220,
        height: 220,
        child: provider == null
            ? const OfflinePhotoPlaceholder()
            : Image(
                image: provider,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const OfflinePhotoPlaceholder(),
              ),
      ),
    );
    return GestureDetector(
      onTap: provider == null
          ? null
          : () {
              // Keep the fast preview-first interaction, then persist the
              // full file once it has been opened. This also works when the
              // signed URL is unavailable: the already-cached preview still
              // opens without a framework error surface.
              unawaited(_cacheOpenedFullAttachment(ref, attachment));
              Navigator.of(context).push(
                telegramRoute<void>(PhotoViewerScreen(imageProvider: provider)),
              );
            },
      child: image,
    );
  }
}

/// Keeps a missing preview recognizable without exposing framework error UI.
/// The muted media glyph is decorative; the surrounding neutral surface keeps
/// the same geometry as a loaded photo (US-047 / FR-41).
class OfflinePhotoPlaceholder extends StatelessWidget {
  const OfflinePhotoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFEAE6E0),
      child: Center(
        child: BlabIcon(
          name: 'media-image - 20',
          size: 24,
          color: Color(0x668C735F),
        ),
      ),
    );
  }
}

Future<void> _cacheOpenedFullAttachment(
  WidgetRef ref,
  MessageAttachment attachment,
) async {
  if (attachment.localBytes != null ||
      attachment.url == null ||
      attachment.url!.isEmpty) {
    return;
  }
  try {
    final response = await http.get(Uri.parse(attachment.url!));
    if (response.statusCode < 200 || response.statusCode >= 300) return;
    await ref
        .read(localChatHistoryCacheProvider)
        ?.saveAttachmentBytes(attachment.id, response.bodyBytes);
  } catch (_) {
    // Best effort only. The preview remains available for offline display.
  }
}

class PhotoViewerScreen extends StatelessWidget {
  const PhotoViewerScreen({super.key, required this.imageProvider});

  final ImageProvider<Object> imageProvider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: BlabAppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image(image: imageProvider, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
