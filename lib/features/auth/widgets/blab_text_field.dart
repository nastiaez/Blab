import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Single styled text field shared across auth and other forms.
/// Bordered, rounded, with optional error message slot.
class BlabTextField extends StatelessWidget {
  const BlabTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.onEditingComplete,
    this.suffix,
    this.autofocus = false,
    this.textInputAction,
    this.focusNode,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final Widget? suffix;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: enabled
                ? BlabColors.textMuted
                : BlabColors.disabledOnSurface,
          ),
        ),
        const SizedBox(height: 6),
        // Wrap the TextField in Semantics so screen readers announce the
        // label — the visible label is rendered above as a styled heading,
        // not via decoration.labelText. PRD US-033.
        Semantics(
          label: label,
          textField: true,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            keyboardType: keyboardType,
            obscureText: obscureText,
            onChanged: onChanged,
            onEditingComplete: onEditingComplete,
            autofocus: autofocus,
            textInputAction: textInputAction,
            cursorColor: BlabColors.brand,
            style: const TextStyle(color: BlabColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: BlabColors.warmMuted),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              filled: true,
              fillColor: enabled
                  ? BlabColors.chatSurface
                  : BlabColors.selectedTint,
              suffixIcon: suffix,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: hasError ? BlabColors.error : BlabColors.chatDivider,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: hasError ? BlabColors.error : BlabColors.focusBorder,
                  width: 1.5,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: BlabColors.divider),
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(fontSize: 12, color: BlabColors.error),
          ),
        ],
      ],
    );
  }
}
