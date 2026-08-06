import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/services/chat_service.dart';

Future<String?> showPhotoPreviewSheet(
  BuildContext context,
  PickedChatImage image,
  String recipientName,
) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        PhotoPreviewSheet(image: image, recipientName: recipientName),
  );
}

class PhotoPreviewSheet extends StatefulWidget {
  const PhotoPreviewSheet({
    super.key,
    required this.image,
    required this.recipientName,
  });

  final PickedChatImage image;
  final String recipientName;

  @override
  State<PhotoPreviewSheet> createState() => _PhotoPreviewSheetState();
}

class _PhotoPreviewSheetState extends State<PhotoPreviewSheet> {
  final _caption = TextEditingController();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = 14 + keyboardInset;
    return ColoredBox(
      key: const ValueKey('photo-preview-fullscreen'),
      color: Colors.black,
      child: SafeArea(
        child: SizedBox.expand(
          child: Stack(
            children: [
              Positioned(
                top: 12,
                left: 16,
                child: Material(
                  color: const Color(0xFF121A20).withValues(alpha: 0.92),
                  shape: const CircleBorder(),
                  child: IconButton(
                    key: const ValueKey('photo-preview-close'),
                    tooltip: context.l10n.cancel,
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
              Positioned.fill(
                top: 76,
                bottom: 142 + keyboardInset,
                child: Center(
                  child: Image.memory(
                    widget.image.bytes,
                    key: const ValueKey('photo-preview-image'),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.image_outlined,
                          color: Colors.white70,
                          size: 56,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 14,
                bottom: bottomPadding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('photo-preview-caption'),
                            controller: _caption,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            style: const TextStyle(color: Colors.white),
                            cursorColor: Colors.white,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Colors.white,
                              ),
                              hintText: 'Add a caption...',
                              hintStyle: const TextStyle(color: Colors.white),
                              filled: true,
                              fillColor: const Color(0xFF121A20),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: Material(
                            color: BlabColors.brand,
                            shape: const CircleBorder(),
                            child: InkWell(
                              key: const ValueKey('photo-preview-send'),
                              customBorder: const CircleBorder(),
                              onTap: () =>
                                  Navigator.of(context).pop(_caption.text),
                              child: Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 30,
                                semanticLabel: context.l10n.send,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF121A20),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        child: Text(
                          widget.recipientName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
