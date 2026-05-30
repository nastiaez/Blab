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

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: BlabColors.textMuted,
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
            keyboardType: keyboardType,
            obscureText: obscureText,
            onChanged: onChanged,
            onEditingComplete: onEditingComplete,
            autofocus: autofocus,
            textInputAction: textInputAction,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: suffix,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? Colors.red.shade400 : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: hasError ? Colors.red.shade400 : BlabColors.brand,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: TextStyle(fontSize: 12, color: Colors.red.shade600),
          ),
        ],
      ],
    );
  }
}
