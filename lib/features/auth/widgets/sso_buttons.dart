import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Apple + Google SSO buttons. PRD US-003.
///
/// Apple is hidden on Android (ship-fast v1 — Apple SSO deferred to Phase 3
/// alongside the iOS build). Both buttons use the same neutral white chip so
/// neither one outweighs the other visually.
class SsoButtons extends StatelessWidget {
  const SsoButtons({super.key, required this.onPressed});

  final ValueChanged<String> onPressed;

  bool get _showApple => !kIsWeb && Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SsoButton(
          label: 'Continue with Google',
          iconWidget: const _GoogleGlyph(),
          onPressed: () => onPressed('google'),
        ),
        if (_showApple) ...[
          const SizedBox(height: 10),
          _SsoButton(
            label: 'Continue with Apple',
            icon: Icons.apple,
            onPressed: () => onPressed('apple'),
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
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: iconWidget ??
            Icon(icon, size: 22, color: BlabColors.textPrimary),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: BlabColors.textPrimary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: BlabColors.phoneSurface,
          side: const BorderSide(color: BlabColors.divider),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

/// Simple "G" glyph in Google's blue. Avoids bundling brand assets.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: Color(0xFF4285F4),
      ),
    );
  }
}
