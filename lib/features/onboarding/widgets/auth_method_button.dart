import 'package:flutter/material.dart';

import '../onboarding_theme.dart';

class AuthMethodButton extends StatelessWidget {
  const AuthMethodButton({
    required this.label,
    required this.leading,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: OnboardingTheme.controlHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: OnboardingTheme.ink,
          backgroundColor: OnboardingTheme.surface,
          side: const BorderSide(color: OnboardingTheme.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OnboardingTheme.controlRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: loading
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : leading,
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
