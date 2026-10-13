import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class BlabExternalLinkRow extends StatelessWidget {
  const BlabExternalLinkRow({
    super.key,
    required this.label,
    required this.onTap,
  });
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    minVerticalPadding: 14,
    minTileHeight: 0,
    title: Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        height: 1.43,
        letterSpacing: 0.25,
        fontWeight: FontWeight.w500,
        color: BlabColors.textPrimary,
      ),
    ),
    trailing: const Icon(
      Icons.open_in_new,
      size: 18,
      color: BlabColors.textMuted,
    ),
  );
}
