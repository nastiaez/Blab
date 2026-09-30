import 'package:flutter/material.dart';

import '../onboarding_theme.dart';

class OnboardingTextField extends StatelessWidget {
  const OnboardingTextField({
    required this.controller,
    required this.label,
    this.errorText,
    this.hintText,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final String? hintText;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText?.isNotEmpty == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: OnboardingTheme.ink,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: OnboardingTheme.controlHeight,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            autofillHints: autofillHints,
            autocorrect: false,
            enableSuggestions: !obscureText,
            obscureText: obscureText,
            enabled: enabled,
            autofocus: autofocus,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            style: const TextStyle(color: OnboardingTheme.ink, fontSize: 17),
            cursorColor: OnboardingTheme.warmInk,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: OnboardingTheme.muted),
              filled: true,
              fillColor: OnboardingTheme.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              suffixIcon: suffix,
              enabledBorder: _border(
                hasError ? OnboardingTheme.error : OnboardingTheme.line,
              ),
              focusedBorder: _border(
                hasError
                    ? OnboardingTheme.error
                    : OnboardingTheme.actionPressed,
                width: 1.5,
              ),
              disabledBorder: _border(OnboardingTheme.line),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 140),
          alignment: Alignment.topCenter,
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Text(
                    errorText!,
                    style: const TextStyle(
                      color: OnboardingTheme.error,
                      fontSize: 13,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(OnboardingTheme.controlRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
