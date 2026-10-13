import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../app/onboarding_tokens.dart';

class BlabAuthMethodButton extends StatelessWidget {
  const BlabAuthMethodButton.onboarding({
    super.key,
    required this.label,
    required this.leading,
    required this.onPressed,
    this.loading = false,
  }) : icon = null,
       intro = true;
  const BlabAuthMethodButton.account({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.icon,
  }) : loading = false,
       intro = false;
  final String label;
  final Widget? leading;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading, intro;
  @override
  Widget build(BuildContext context) =>
      intro ? _onboarding(context) : _account(context);
  Widget _onboarding(BuildContext context) {
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
                  : leading!,
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

  Widget _account(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon:
            leading ??
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
