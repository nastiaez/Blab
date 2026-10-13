import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../blab_switch.dart';

class BlabSettingSwitchRow extends StatelessWidget {
  const BlabSettingSwitchRow({
    super.key,
    required this.label,
    required this.caption,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String caption;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minTileHeight: 0,
        minVerticalPadding: 12,
        horizontalTitleGap: 12,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                height: 1.43,
                letterSpacing: 0.25,
                fontWeight: FontWeight.w500,
                color: BlabColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              caption,
              style: const TextStyle(
                fontSize: 12,
                color: BlabColors.textMuted,
                height: 1.35,
                letterSpacing: 0.25,
              ),
            ),
          ],
        ),
        trailing: BlabSwitch(value: value, onChanged: onChanged),
      ),
    );
  }
}
