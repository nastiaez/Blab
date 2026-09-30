import 'package:flutter/material.dart';

import '../onboarding_theme.dart';

class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return DecoratedBox(
      key: const Key('primary-action-shadow'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(OnboardingTheme.controlRadius),
        boxShadow: enabled
            ? const [
                BoxShadow(
                  color: Color(0x24231208),
                  offset: Offset(0, 8),
                  blurRadius: 22,
                ),
              ]
            : const [],
      ),
      child: SizedBox(
        key: const Key('primary-action'),
        width: double.infinity,
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: ButtonStyle(
            elevation: const WidgetStatePropertyAll(0),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return OnboardingTheme.line;
              }
              if (states.contains(WidgetState.pressed)) {
                return OnboardingTheme.actionPressed;
              }
              return OnboardingTheme.action;
            }),
            foregroundColor: const WidgetStatePropertyAll(
              OnboardingTheme.warmInk,
            ),
            minimumSize: const WidgetStatePropertyAll(
              Size.fromHeight(OnboardingTheme.controlHeight),
            ),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  OnboardingTheme.controlRadius,
                ),
              ),
            ),
            textStyle: const WidgetStatePropertyAll(
              OnboardingTheme.buttonLabel,
            ),
          ),
          child: loading
              ? const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: OnboardingTheme.warmInk,
                  ),
                )
              : Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
