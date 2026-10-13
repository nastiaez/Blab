import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../app/onboarding_tokens.dart';

enum BlabFormAppearance { account, onboarding }

class BlabFormField extends StatelessWidget {
  const BlabFormField.account({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.errorText,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.suffix,
    this.autofocus = false,
    this.textInputAction,
    this.focusNode,
    this.enabled = true,
    this.autofillHints,
  }) : appearance = BlabFormAppearance.account;
  const BlabFormField.onboarding({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.errorText,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.suffix,
    this.autofocus = false,
    this.textInputAction,
    this.focusNode,
    this.enabled = true,
    this.autofillHints,
  }) : appearance = BlabFormAppearance.onboarding;
  final BlabFormAppearance appearance;
  final TextEditingController controller;
  final String label;
  final String? hintText, errorText;
  final TextInputType? keyboardType;
  final bool obscureText, autofocus, enabled;
  final ValueChanged<String>? onChanged, onSubmitted;
  final VoidCallback? onEditingComplete;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  @override
  Widget build(BuildContext context) {
    final introTheme = BlabOnboardingTheme.of(context);
    final intro = appearance == BlabFormAppearance.onboarding;
    final hasError = errorText?.isNotEmpty == true;
    final ink = intro ? introTheme.ink : BlabColors.textPrimary;
    final line = intro ? introTheme.line : BlabColors.chatDivider;
    final error = intro ? introTheme.error : BlabColors.error;
    final radius = intro ? 16.0 : 14.0;
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color, width: width),
        );
    Widget field = TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      autocorrect: intro ? false : true,
      enableSuggestions: intro ? !obscureText : true,
      cursorColor: intro ? OnboardingTheme.warmInk : BlabColors.brand,
      style: TextStyle(color: ink, fontSize: intro ? 17 : null),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: intro ? OnboardingTheme.muted : BlabColors.warmMuted,
        ),
        isDense: !intro,
        filled: true,
        fillColor: intro
            ? introTheme.surface
            : (enabled ? BlabColors.chatSurface : BlabColors.selectedTint),
        contentPadding: intro
            ? const EdgeInsets.symmetric(horizontal: 16)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        suffixIcon: suffix,
        enabledBorder: border(hasError ? error : line),
        focusedBorder: border(
          hasError
              ? error
              : (intro
                    ? OnboardingTheme.actionPressed
                    : BlabColors.focusBorder),
          width: 1.5,
        ),
        disabledBorder: border(intro ? introTheme.line : BlabColors.divider),
      ),
    );
    if (intro) {
      field = SizedBox(height: OnboardingTheme.controlHeight, child: field);
    }
    field = Semantics(label: label, textField: true, child: field);
    final errorWidget = hasError
        ? Padding(
            padding: intro
                ? const EdgeInsets.only(top: 6, left: 2)
                : const EdgeInsets.only(top: 6),
            child: Text(
              errorText!,
              style: TextStyle(fontSize: intro ? 13 : 12, color: error),
            ),
          )
        : const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          intro ? label : label.toUpperCase(),
          style: intro
              ? TextStyle(
                  color: introTheme.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                )
              : TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: enabled
                      ? BlabColors.textMuted
                      : BlabColors.disabledOnSurface,
                ),
        ),
        SizedBox(height: intro ? 7 : 6),
        field,
        if (intro)
          AnimatedSize(
            duration: const Duration(milliseconds: 140),
            alignment: Alignment.topCenter,
            child: errorWidget,
          )
        else
          errorWidget,
      ],
    );
  }
}
