import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// iOS-style switch. Cupertino keeps the thumb size constant across both
/// states (Material 3's thumb shrinks when off, which we don't want) and
/// has no outline. Scaled 88 % to sit comfortably in row layouts.
class BlabSwitch extends StatelessWidget {
  const BlabSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.88,
      child: CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: BlabColors.brand,
        inactiveTrackColor: BlabColors.divider,
        thumbColor: Colors.white,
      ),
    );
  }
}
