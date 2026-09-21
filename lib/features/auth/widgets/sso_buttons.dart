import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';

/// Apple + Google SSO buttons. PRD US-003.
///
/// Apple is hidden on Android (ship-fast v1 — Apple SSO deferred to Phase 3
/// alongside the iOS build). Both buttons use the same warm neutral surface so
/// neither one outweighs the other visually.
class SsoButtons extends StatelessWidget {
  const SsoButtons({super.key, required this.onPressed, this.enabled = true});

  final ValueChanged<String> onPressed;
  final bool enabled;

  bool get _showApple => !kIsWeb && Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SsoButton(
          label: context.l10n.continueWithGoogle,
          iconWidget: _GoogleGlyph(enabled: enabled),
          onPressed: enabled ? () => onPressed('google') : null,
        ),
        if (_showApple) ...[
          const SizedBox(height: 10),
          _SsoButton(
            label: context.l10n.continueWithApple,
            icon: Icons.apple,
            onPressed: enabled ? () => onPressed('apple') : null,
          ),
        ],
      ],
    );
  }
}

class _SsoButton extends StatelessWidget {
  const _SsoButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.iconWidget,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon:
            iconWidget ??
            Icon(
              icon,
              size: 22,
              color: onPressed == null
                  ? BlabColors.disabledOnSurface
                  : BlabColors.textPrimary,
            ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: onPressed == null
                ? BlabColors.disabledOnSurface
                : BlabColors.textPrimary,
          ),
        ),
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? BlabColors.selectedTint
                : BlabColors.chatSurface,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: BlabColors.chatDivider),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}

/// Simple "G" glyph in Google's blue. Avoids bundling brand assets.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Text(
      'G',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: enabled ? const Color(0xFF4285F4) : BlabColors.disabledOnSurface,
      ),
    );
  }
}
