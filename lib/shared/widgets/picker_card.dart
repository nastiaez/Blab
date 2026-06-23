import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../data/languages.dart';

// Spring overshoot curve for scale-back on tap release.
const _kSpring = Cubic(0.34, 1.56, 0.64, 1);

/// Tappable language card used across all language pickers.
///
/// Scale-press interaction (no Material ripple) so there is no gray flash.
/// Border width is constant (2 px) — only color changes on select, so
/// adjacent cards never shift position.
class LanguageCard extends StatefulWidget {
  const LanguageCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<LanguageCard> createState() => _LanguageCardState();
}

class _LanguageCardState extends State<LanguageCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
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
    return Semantics(
      selected: widget.selected,
      button: true,
      child: GestureDetector(
        onTapDown: (_) => _press.forward(),
        onTapUp: (_) {
          _press.reverse();
          widget.onTap();
        },
        onTapCancel: () => _press.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: widget.selected
                  ? BlabColors.brand.withValues(alpha: 0.12)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                // Always 2 px — only color changes, no layout shift.
                color: widget.selected
                    ? BlabColors.brand
                    : Colors.grey.shade200,
                width: 2,
              ),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      widget.selected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.selected
                      ? BlabColors.brand
                      : BlabColors.textPrimary,
                ),
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
    return GestureDetector(
      onTapDown: _enabled ? (_) => _press.forward() : null,
      onTapUp: _enabled
          ? (_) {
              _press.reverse();
              widget.onPressed!();
            }
          : null,
      onTapCancel: _enabled ? () => _press.reverse() : null,
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _enabled ? BlabColors.brand : BlabColors.disabledSurface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: widget.loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _enabled
                          ? Colors.white
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
LanguageCard languageCardEn(BlabLanguage lang,
        {required bool selected, required VoidCallback onTap}) =>
    LanguageCard(
      label: lang.name,
      selected: selected,
      onTap: onTap,
    );

/// Convenience: build a [LanguageCard] from a [BlabLanguage], using the
/// native name (for interface-language picker).
LanguageCard languageCardNative(BlabLanguage lang,
        {required bool selected, required VoidCallback onTap}) =>
    LanguageCard(
      label: lang.nativeName,
      selected: selected,
      onTap: onTap,
    );
