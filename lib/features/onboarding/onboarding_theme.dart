import 'package:flutter/material.dart';

import '../../app/theme.dart';

abstract final class OnboardingTheme {
  static const canvas = BlabColors.cream;
  static const surface = Color(0xFFFFFFFF);
  static const warmSurface = Color(0xFFFFFCF8);
  static const action = Color(0xFFF88C5A);
  static const actionPressed = Color(0xFFE66F40);
  static const ink = Color(0xFF1F3340);
  static const warmInk = Color(0xFF46281C);
  static const muted = Color(0xFF69737B);
  static const line = Color(0xFFE4DCCC);
  static const error = Color(0xFFB83A35);
  static const selectedTint = Color(0xFFF7EFE5);

  static const horizontalGutter = 20.0;
  static const controlHeight = 56.0;
  static const controlRadius = 16.0;
  static const minimumTapTarget = 44.0;

  static const headline = TextStyle(
    color: ink,
    fontSize: 34,
    height: 1.04,
    letterSpacing: -1.35,
    fontWeight: FontWeight.w800,
  );

  static const buttonLabel = TextStyle(
    color: warmInk,
    fontSize: 16,
    height: 1.2,
    fontWeight: FontWeight.w700,
  );
}
