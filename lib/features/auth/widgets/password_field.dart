import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import 'blab_text_field.dart';

/// Password field with show/hide eye toggle. PRD US-001, FR-2.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label,
    this.errorText,
    this.onChanged,
    this.textInputAction,
    this.autofocus = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String? label;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool enabled;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return BlabTextField(
      controller: widget.controller,
      label: widget.label ?? context.l10n.password,
      obscureText: _hidden,
      errorText: widget.errorText,
      onChanged: widget.onChanged,
      textInputAction: widget.textInputAction,
      autofocus: widget.autofocus,
      enabled: widget.enabled,
      suffix: IconButton(
        icon: Icon(
          _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: !widget.enabled
              ? BlabColors.disabledOnSurface
              : (_hidden ? BlabColors.warmMuted : BlabColors.brand),
          size: 20,
        ),
        onPressed: widget.enabled
            ? () => setState(() => _hidden = !_hidden)
            : null,
        tooltip: _hidden
            ? context.l10n.showPassword
            : context.l10n.hidePassword,
      ),
    );
  }
}
