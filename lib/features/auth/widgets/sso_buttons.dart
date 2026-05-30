import 'package:flutter/material.dart';

/// Apple + Google SSO buttons. PRD US-003.
///
/// Both buttons are shown regardless of platform so the surface matches the
/// PRD spec everywhere (including the invite-signup screen). Runtime auth
/// wiring lands in Phase 2 — until then, taps are mock-handled by the caller.
class SsoButtons extends StatelessWidget {
  const SsoButtons({super.key, required this.onPressed});

  final ValueChanged<String> onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SsoButton(
          label: 'Continue with Apple',
          icon: Icons.apple,
          background: Colors.black,
          foreground: Colors.white,
          onPressed: () => onPressed('apple'),
        ),
        const SizedBox(height: 10),
        _SsoButton(
          label: 'Continue with Google',
          iconWidget: const _GoogleGlyph(),
          background: Colors.white,
          foreground: Colors.black87,
          border: Colors.grey.shade300,
          onPressed: () => onPressed('google'),
        ),
      ],
    );
  }
}

class _SsoButton extends StatelessWidget {
  const _SsoButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.icon,
    this.iconWidget,
    this.border,
  });

  final String label;
  final IconData? icon;
  final Widget? iconWidget;
  final Color background;
  final Color foreground;
  final Color? border;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: iconWidget ?? Icon(icon, size: 22, color: foreground),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: foreground,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          side: BorderSide(color: border ?? background),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

/// Simple 4-color "G" mark. Standalone glyph to avoid bundling Google brand assets.
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
