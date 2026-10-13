import 'package:flutter/material.dart';
import '../../../app/theme.dart';

class BlabSectionDivider extends StatelessWidget {
  const BlabSectionDivider({
    super.key,
    this.inset = 16,
    this.color = BlabColors.chatDivider,
  });
  final double inset;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: inset),
    child: Divider(height: 1, thickness: 1, color: color),
  );
}
