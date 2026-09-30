import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../onboarding_theme.dart';
import 'onboarding_text_field.dart';

class OnboardingPasswordField extends StatefulWidget {
  const OnboardingPasswordField({
    required this.controller,
    required this.label,
    this.errorText,
    this.focusNode,
    this.enabled = true,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final FocusNode? focusNode;
  final bool enabled;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<OnboardingPasswordField> createState() =>
      _OnboardingPasswordFieldState();
}

class _OnboardingPasswordFieldState extends State<OnboardingPasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return OnboardingTextField(
      controller: widget.controller,
      label: widget.label,
      errorText: widget.errorText,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: _obscured,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      suffix: IconButton(
        tooltip: _obscured
            ? context.l10n.showPassword
            : context.l10n.hidePassword,
        onPressed: widget.enabled
            ? () => setState(() => _obscured = !_obscured)
            : null,
        icon: Icon(
          _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: OnboardingTheme.muted,
          size: 21,
        ),
      ),
    );
  }
}
