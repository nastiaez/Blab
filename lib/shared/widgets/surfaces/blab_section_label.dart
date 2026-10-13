import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Native text with the intentional account/partner section-heading variants.
class BlabSectionLabel extends StatelessWidget {
  const BlabSectionLabel.account(this.label, {super.key}) : partner = false;
  const BlabSectionLabel.partner(this.label, {super.key}) : partner = true;
  final String label;
  final bool partner;
  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: TextStyle(
      fontSize: 11,
      fontWeight: partner ? FontWeight.w700 : FontWeight.w600,
      color: BlabColors.warmMuted,
      letterSpacing: partner ? .8 : .25,
      height: 1.43,
    ),
  );
}
