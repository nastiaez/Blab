import 'package:flutter/material.dart';

/// Design tokens. Source of truth: PRD § Design Principles + tech-spec
/// Resolved Decision #16 (orange palette + cream surfaces).
class BlabColors {
  const BlabColors._();

  // Brand
  static const Color brand = Color(0xFFD4694A); // sunset orange
  static const Color brandPress = Color(0xFFBB573B);
  static const Color brandSoft = Color(0xFFF3DAD0); // bubble fill / soft accent

  // Surfaces
  static const Color cream = Color(0xFFEFEBE2); // app bg + chat canvas
  static const Color appBackground = cream;
  static const Color phoneSurface = Color(0xFFFFFFFF); // headers, sheets, incoming bubble
  static const Color fieldBackground = Color(0xFFFFFFFF);

  // Ink
  static const Color textPrimary = Color(0xFF1F3340); // ink
  static const Color textMuted = Color(0xFF5F6770); // stone — darkened for WCAG AA (4.5:1 on cream + bubble blue-gray)

  // Incoming bubble (soft blue-gray from kit secondary token).
  static const Color bubbleIncoming = Color(0xFFD6E2E7);

  // Hairline
  static const Color divider = Color(0xFFE4DCCC); // line

  // Focus border for inputs — 75 % brand orange, clearly distinct from
  // the resting `divider` border but quieter than full brand.
  static const Color focusBorder = Color(0xBFD4694A);

  // Error / destructive state — cooler deep red, WCAG-AA on cream + white.
  static const Color error = Color(0xFFC62828);

  // Disabled state for buttons / interactive surfaces.
  static const Color disabledSurface = Color(0xFFE4DCCC); // = divider
  static const Color disabledOnSurface = Color(0xFF9A9490);

  // Selected row tint (used by language picker, etc.)
  static const Color selectedTint = Color(0xFFFAF1EC);

  // Avatar palette — deterministic non-brand swatches so partners don't
  // compete with the orange accent. Excludes brand orange on purpose.
  static const List<Color> avatarPalette = [
    Color(0xFF5E8B8C), // teal
    Color(0xFFC99846), // mustard
    Color(0xFF1F3340), // ink
    Color(0xFF9A6A8C), // plum
    Color(0xFF5F7A52), // sage
  ];

  /// Stable color per name/initial.
  static Color avatarColorFor(String name) {
    if (name.isEmpty) return avatarPalette.first;
    var sum = 0;
    for (final code in name.codeUnits) {
      sum += code;
    }
    return avatarPalette[sum % avatarPalette.length];
  }
}

final ThemeData blabTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: BlabColors.brand,
    primary: BlabColors.brand,
    surface: BlabColors.phoneSurface,
  ),
  scaffoldBackgroundColor: BlabColors.appBackground,
);
