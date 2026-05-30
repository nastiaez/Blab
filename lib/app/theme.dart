import 'package:flutter/material.dart';

/// Design tokens. Mirror of prototype.html § :root + Design Principles in PRD.
///
/// PRD § Design Principles: brand purple, iOS-native feel, system font.
/// Prototype reference: body bg `#f0f0f5`, brand `#5B4FE8`.
class BlabColors {
  const BlabColors._();

  static const Color brand = Color(0xFF5B4FE8);
  static const Color appBackground = Color(0xFFF0F0F5);
  static const Color phoneSurface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF111111);
  static const Color textMuted = Color(0xFF888888);
  static const Color divider = Color(0xFFEEEEEE);
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
  // System font stack — Material defaults to Roboto on Android, SF on iOS.
  // Leaving fontFamily null = use platform default. PRD § Design Principles.
);
