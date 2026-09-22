import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../data/languages.dart';
import 'blab_icon.dart';

// Spring overshoot curve for scale-back on tap release.
const _kSpring = Cubic(0.34, 1.56, 0.64, 1);

/// Tappable language row used by the full-screen language pickers.
///
/// Mirrors the approved learning-language sheet: quiet unselected rows,
/// a warm selected fill, and a trailing check without card outlines.
class LanguageCard extends StatelessWidget {
  const LanguageCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? BlabColors.languageSelectionTint : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.2,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: BlabColors.bubbleInk,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                  if (selected) ...[
                    const SizedBox(width: 12),
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
        ),
      ),
    );
  }
}

/// Primary brand CTA button without any Flutter-managed color transition.
///
/// Replaces FilledButton so disabled→enabled color change is our animation
/// (no gray flash on the label text).
class BrandButton extends StatefulWidget {
  const BrandButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  State<BrandButton> createState() => _BrandButtonState();
}

class _BrandButtonState extends State<BrandButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _press,
        curve: Curves.easeIn,
        reverseCurve: _kSpring,
      ),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Match FilledButton's M3 disabled background so loading and
    // disabled states look consistent across all button types.
    final disabledColor = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.12);

    Color bgColor;
    if (!_enabled) {
      bgColor = disabledColor;
    } else if (_pressed) {
      bgColor = BlabColors.brandPress;
    } else {
      bgColor = BlabColors.brand;
    }

    return GestureDetector(
      onTapDown: _enabled
          ? (_) {
              setState(() => _pressed = true);
              _press.forward();
            }
          : null,
      onTapUp: _enabled
          ? (_) {
              setState(() => _pressed = false);
              _press.reverse();
              widget.onPressed!();
            }
          : null,
      onTapCancel: _enabled
          ? () {
              setState(() => _pressed = false);
              _press.reverse();
            }
          : null,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        BlabColors.warmInk,
                      ),
                    ),
                  )
                : Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _enabled
                          ? BlabColors.warmInk
                          : BlabColors.disabledOnSurface,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Convenience: build a [LanguageCard] from a [BlabLanguage], using the
/// English name (for learning pickers).
LanguageCard languageCardEn(
  BlabLanguage lang, {
  required bool selected,
  required VoidCallback onTap,
}) => LanguageCard(label: lang.name, selected: selected, onTap: onTap);

/// Convenience: build a [LanguageCard] from a [BlabLanguage], using the
/// native name (for interface-language picker).
LanguageCard languageCardNative(
  BlabLanguage lang, {
  required bool selected,
  required VoidCallback onTap,
}) => LanguageCard(label: lang.nativeName, selected: selected, onTap: onTap);
