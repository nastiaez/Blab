import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Photo action sheet. PRD US-011.
/// Tapping any row just closes the sheet for now (no real picker yet).
/// "Remove photo" only appears when a photo actually exists.
Future<void> showPhotoSheet(BuildContext context, {bool hasPhoto = false}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _PhotoRow(
              icon: Icons.photo_camera_outlined,
              label: 'Take photo',
              onTap: () => Navigator.of(ctx).pop(),
            ),
            _Divider(),
            _PhotoRow(
              icon: Icons.photo_library_outlined,
              label: 'Choose from library',
              onTap: () => Navigator.of(ctx).pop(),
            ),
            if (hasPhoto) ...[
              _Divider(),
              _PhotoRow(
                icon: Icons.delete_outline,
                label: 'Remove photo',
                destructive: true,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.red.shade400 : BlabColors.textPrimary;
    final iconColor =
        destructive ? Colors.red.shade400 : BlabColors.textMuted;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56),
      child: Divider(height: 1, color: Colors.grey.shade100),
    );
  }
}
