import 'package:flutter/material.dart';

/// Shared Material multiline editing engine. Owners supply appearance and
/// keep draft, reply, attachment, limits and send behavior outside the field.
class BlabComposerField extends StatelessWidget {
  const BlabComposerField({
    super.key,
    this.fieldKey,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.autofocus = false,
    this.keyboardType,
    this.onTap,
    this.minLines = 1,
    this.maxLines = 5,
    this.maxLength,
    this.buildCounter,
    this.style,
    this.decoration,
    this.cursorColor,
    this.textCapitalization = TextCapitalization.sentences,
  });
  final Key? fieldKey;
  final TextInputType? keyboardType;
  final VoidCallback? onTap;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled, autofocus;
  final int? minLines, maxLines, maxLength;
  final InputCounterWidgetBuilder? buildCounter;
  final TextStyle? style;
  final InputDecoration? decoration;
  final Color? cursorColor;
  final TextCapitalization textCapitalization;
  @override
  Widget build(BuildContext context) => TextField(
    key: fieldKey,
    controller: controller,
    focusNode: focusNode,
    enabled: enabled,
    autofocus: autofocus,
    keyboardType: keyboardType,
    onTap: onTap,
    minLines: minLines,
    maxLines: maxLines,
    maxLength: maxLength,
    buildCounter: buildCounter,
    style: style,
    decoration: decoration,
    cursorColor: cursorColor,
    textCapitalization: textCapitalization,
  );
}
