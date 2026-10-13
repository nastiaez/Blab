import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../data/languages.dart';
import '../blab_icon.dart';

/// Tappable language row used by the full-screen language pickers.
///
/// Mirrors the approved learning-language sheet: quiet unselected rows,
/// a warm selected fill, and a trailing check without card outlines.
class BlabSelectionRow extends StatelessWidget {
  const BlabSelectionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? BlabColors.languageSelectionTint : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minTileHeight: 48,
          minVerticalPadding: 0,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              height: 1.2,
              letterSpacing: 0.25,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              color: BlabColors.bubbleInk,
            ),
          ),
          trailing: trailing == null && !selected
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ?trailing,
                    if (selected) ...[
                      if (trailing != null) const SizedBox(width: 12),
                      const BlabIcon(
                        name: 'check - 20',
                        size: 18,
                        color: BlabColors.bubbleInk,
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Convenience: build a [BlabSelectionRow] from a [BlabLanguage], using the
/// English name (for learning pickers).
BlabSelectionRow languageCardEn(
  BlabLanguage lang, {
  required bool selected,
  required VoidCallback onTap,
}) => BlabSelectionRow(label: lang.name, selected: selected, onTap: onTap);

/// Convenience: build a [BlabSelectionRow] from a [BlabLanguage], using the
/// native name (for interface-language picker).
BlabSelectionRow languageCardNative(
  BlabLanguage lang, {
  required bool selected,
  required VoidCallback onTap,
}) =>
    BlabSelectionRow(label: lang.nativeName, selected: selected, onTap: onTap);
