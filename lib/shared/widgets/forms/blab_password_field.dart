import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../app/onboarding_tokens.dart';
import 'blab_form_field.dart';

class BlabPasswordField extends StatefulWidget {
  const BlabPasswordField.account({
    super.key,
    required this.controller,
    this.label,
    this.errorText,
    this.focusNode,
    this.enabled = true,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    this.autofocus = false,
  }) : appearance = BlabFormAppearance.account;
  const BlabPasswordField.onboarding({
    super.key,
    required this.controller,
    this.label,
    this.errorText,
    this.focusNode,
    this.enabled = true,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.autofillHints,
    this.autofocus = false,
  }) : appearance = BlabFormAppearance.onboarding;
  final TextEditingController controller;
  final String? label, errorText;
  final FocusNode? focusNode;
  final bool enabled, autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged, onSubmitted;
  final Iterable<String>? autofillHints;
  final BlabFormAppearance appearance;
  @override
  State<BlabPasswordField> createState() => _BlabPasswordFieldState();
}

class _BlabPasswordFieldState extends State<BlabPasswordField> {
  bool _obscured = true;
  @override
  Widget build(BuildContext context) {
    final intro = widget.appearance == BlabFormAppearance.onboarding;
    final suffix = IconButton(
      tooltip: _obscured
          ? context.l10n.showPassword
          : context.l10n.hidePassword,
      onPressed: widget.enabled
          ? () => setState(() => _obscured = !_obscured)
          : null,
      icon: Icon(
        intro
            ? (_obscured
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined)
            : (_obscured
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
        color: intro
            ? OnboardingTheme.muted
            : (!widget.enabled
                  ? BlabColors.disabledOnSurface
                  : (_obscured ? BlabColors.warmMuted : BlabColors.brand)),
        size: intro ? 21 : 20,
      ),
    );
    final field = intro ? BlabFormField.onboarding : BlabFormField.account;
    return field(
      controller: widget.controller,
      label: widget.label ?? context.l10n.password,
      errorText: widget.errorText,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      obscureText: _obscured,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      autofocus: widget.autofocus,
      suffix: suffix,
    );
  }
}
