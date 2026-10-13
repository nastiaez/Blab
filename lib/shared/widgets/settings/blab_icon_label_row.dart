import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Icon-label ListTile variants without inventing a trailing navigation action.
class BlabIconLabelRow extends StatelessWidget {
  const BlabIconLabelRow.partnerSafety({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  }) : warning = false;
  const BlabIconLabelRow.accountWarning({super.key, required this.label})
    : icon = Icons.warning_amber_outlined,
      onTap = null,
      destructive = false,
      warning = true;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive, warning;
  @override
  Widget build(BuildContext context) {
    final ink = warning
        ? BlabColors.textPrimary
        : (destructive ? BlabColors.error : BlabColors.warmInk);
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minTileHeight: warning ? 0 : 56,
      minVerticalPadding: warning ? 14 : 12,
      minLeadingWidth: warning ? 20 : 22,
      horizontalTitleGap: 14,
      titleAlignment: ListTileTitleAlignment.center,
      leading: Icon(
        icon,
        size: warning ? 20 : 22,
        color: warning ? BlabColors.error : ink,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: ink,
          fontSize: 15,
          height: 1.43,
          letterSpacing: 0.25,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
