import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'blab_text_field.dart';

/// Password field with show/hide eye toggle. PRD US-001, FR-2.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.errorText,
    this.onChanged,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return BlabTextField(
      controller: widget.controller,
      label: widget.label,
      obscureText: _hidden,
      errorText: widget.errorText,
      onChanged: widget.onChanged,
      textInputAction: widget.textInputAction,
      suffix: IconButton(
        icon: Icon(
          _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: _hidden ? Colors.grey.shade500 : BlabColors.brand,
          size: 20,
        ),
        onPressed: () => setState(() => _hidden = !_hidden),
        tooltip: _hidden ? 'Show password' : 'Hide password',
      ),
    );
  }
}
