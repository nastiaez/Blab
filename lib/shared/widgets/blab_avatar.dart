import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// One avatar renderer with named geometry supplied by the owning surface.
class BlabAvatar extends StatelessWidget {
  const BlabAvatar({
    super.key,
    required this.name,
    this.size = 48,
    this.fontSize = 16,
    this.initials,
    this.fontWeight = FontWeight.w800,
    this.shadows = const [
      BoxShadow(color: Color(0x2B231208), offset: Offset(0, 2), blurRadius: 6),
    ],
  });
  final String name;
  final String? initials;
  final double size, fontSize;
  final FontWeight fontWeight;
  final List<BoxShadow>? shadows;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: BlabColors.avatarColorFor(name),
      boxShadow: shadows,
    ),
    alignment: Alignment.center,
    child: Material(
      type: MaterialType.transparency,
      shape: const CircleBorder(),
      child: Center(
        child: Text(
          initials ?? BlabColors.avatarInitialsFor(name),
          style: TextStyle(
            color: Colors.white,
            fontWeight: fontWeight,
            fontSize: fontSize,
          ),
        ),
      ),
    ),
  );
}
