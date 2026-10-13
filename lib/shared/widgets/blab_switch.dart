import 'package:flutter/material.dart';

/// Controlled Material 3 switch. State and persistence remain with its caller.
class BlabSwitch extends StatelessWidget {
  const BlabSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) =>
      Switch(value: value, onChanged: onChanged);
}
