import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Renders a built-in app icon or tints a custom SVG at runtime.
class BlabIcon extends StatelessWidget {
  const BlabIcon({
    super.key,
    required this.name,
    required this.color,
    this.size = 24,
  });

  /// File stem under `assets/icons/` (e.g. `chat`, `profile`, `sound`).
  final String name;
  final Color color;
  final double size;

  static const _materialIcons = <String, IconData>{
    'globe': Icons.language,
    'chat': Icons.chat_bubble_outline,
    'profile': Icons.person_outline,
  };

  @override
  Widget build(BuildContext context) {
    final materialIcon = _materialIcons[name];
    if (materialIcon != null) {
      return Icon(materialIcon, color: color, size: size);
    }
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
