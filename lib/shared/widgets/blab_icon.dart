import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Tints a single-color SVG line icon at runtime.
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

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
