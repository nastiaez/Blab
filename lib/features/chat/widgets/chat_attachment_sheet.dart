import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../services/chat_image_picker.dart';

class ChatAttachmentTray extends StatelessWidget {
  const ChatAttachmentTray({super.key, required this.onPick});

  final ValueChanged<ChatImageSource> onPick;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        children: [
          _AttachmentTile(
            key: const ValueKey('attachment-tile-gallery'),
            icon: Icons.photo_library_outlined,
            label: 'Gallery',
            onTap: () => onPick(ChatImageSource.gallery),
          ),
          const SizedBox(width: 18),
          _AttachmentTile(
            key: const ValueKey('attachment-tile-camera'),
            icon: Icons.photo_camera_outlined,
            label: 'Camera',
            onTap: () => onPick(ChatImageSource.camera),
          ),
        ],
      ),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: BlabColors.selectedTint,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BlabColors.divider),
                ),
                child: Icon(icon, size: 32, color: BlabColors.brand),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: BlabColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
