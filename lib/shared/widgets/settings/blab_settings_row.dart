import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../blab_icon.dart';

class BlabSettingsRow extends StatelessWidget {
  const BlabSettingsRow({
    super.key,
    required this.iconName,
    required this.label,
    required this.onTap,
    this.trailingLabel,
    this.destructive = false,
  });

  final String iconName;
  final String label;
  final VoidCallback onTap;
  final String? trailingLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.75;
    final iconSize = largeText ? 24.0 : 20.0;
    final Color iconColor = destructive
        ? BlabColors.error
        : BlabColors.textMuted;
    final Color labelColor = destructive
        ? BlabColors.error
        : const Color(0xFF46281C);
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: largeText ? 18 : 16),
      minTileHeight: 0,
      minVerticalPadding: largeText ? 18 : 14,
      minLeadingWidth: iconSize,
      horizontalTitleGap: largeText ? 18 : 14,
      leading: BlabIcon(name: iconName, size: iconSize, color: iconColor),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              height: 1.43,
              letterSpacing: 0.25,
              fontWeight: FontWeight.w400,
              color: labelColor,
            ),
          ),
          if (largeText && trailingLabel != null) ...[
            const SizedBox(height: 4),
            Text(
              trailingLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.43,
                letterSpacing: 0.25,
                fontWeight: FontWeight.w400,
                color: BlabColors.textMuted,
              ),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!largeText && trailingLabel != null) ...[
            Text(
              trailingLabel!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.43,
                letterSpacing: 0.25,
                fontWeight: FontWeight.w400,
                color: BlabColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),
          ],
          BlabIcon(
            name: 'nav-arrow-right - 20',
            color: iconColor,
            size: iconSize,
          ),
        ],
      ),
    );
  }
}
