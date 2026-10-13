import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'onboarding_tokens.dart';

/// Scoped component roles. Similar-looking historical colors intentionally
/// remain separate tokens rather than silently changing another surface.
@immutable
class BlabComponentTheme extends ThemeExtension<BlabComponentTheme> {
  const BlabComponentTheme({
    this.surface = BlabColors.chatSurface,
    this.outline = BlabColors.chatDivider,
    this.settingsInk = BlabColors.warmInk,
    this.settingsMuted = BlabColors.textMuted,
    this.cardRadius = 16,
    this.selectionRadius = 12,
  });
  final Color surface, outline, settingsInk, settingsMuted;
  final double cardRadius, selectionRadius;
  static BlabComponentTheme of(BuildContext context) =>
      Theme.of(context).extension<BlabComponentTheme>() ??
      const BlabComponentTheme();
  @override
  BlabComponentTheme copyWith({
    Color? surface,
    Color? outline,
    Color? settingsInk,
    Color? settingsMuted,
    double? cardRadius,
    double? selectionRadius,
  }) => BlabComponentTheme(
    surface: surface ?? this.surface,
    outline: outline ?? this.outline,
    settingsInk: settingsInk ?? this.settingsInk,
    settingsMuted: settingsMuted ?? this.settingsMuted,
    cardRadius: cardRadius ?? this.cardRadius,
    selectionRadius: selectionRadius ?? this.selectionRadius,
  );
  @override
  BlabComponentTheme lerp(covariant BlabComponentTheme? other, double t) {
    if (other == null) return this;
    return BlabComponentTheme(
      surface: Color.lerp(surface, other.surface, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      settingsInk: Color.lerp(settingsInk, other.settingsInk, t)!,
      settingsMuted: Color.lerp(settingsMuted, other.settingsMuted, t)!,
      cardRadius: cardRadius + (other.cardRadius - cardRadius) * t,
      selectionRadius:
          selectionRadius + (other.selectionRadius - selectionRadius) * t,
    );
  }
}

@immutable
class BlabChatTheme extends ThemeExtension<BlabChatTheme> {
  const BlabChatTheme({
    this.incoming = BlabColors.bubbleIncomingSurface,
    this.incomingOutline = BlabColors.bubbleIncomingOutline,
    this.normal = BlabColors.bubbleOutgoingNormal,
    this.normalOutline = BlabColors.bubbleOutgoingNormalOutline,
    this.practice = BlabColors.bubbleOutgoingPractice,
    this.practiceOutline = BlabColors.bubbleOutgoingPracticeOutline,
  });
  final Color incoming,
      incomingOutline,
      normal,
      normalOutline,
      practice,
      practiceOutline;
  static BlabChatTheme of(BuildContext context) =>
      Theme.of(context).extension<BlabChatTheme>() ?? const BlabChatTheme();
  @override
  BlabChatTheme copyWith({
    Color? incoming,
    Color? incomingOutline,
    Color? normal,
    Color? normalOutline,
    Color? practice,
    Color? practiceOutline,
  }) => BlabChatTheme(
    incoming: incoming ?? this.incoming,
    incomingOutline: incomingOutline ?? this.incomingOutline,
    normal: normal ?? this.normal,
    normalOutline: normalOutline ?? this.normalOutline,
    practice: practice ?? this.practice,
    practiceOutline: practiceOutline ?? this.practiceOutline,
  );
  @override
  BlabChatTheme lerp(covariant BlabChatTheme? other, double t) {
    if (other == null) return this;
    return BlabChatTheme(
      incoming: Color.lerp(incoming, other.incoming, t)!,
      incomingOutline: Color.lerp(incomingOutline, other.incomingOutline, t)!,
      normal: Color.lerp(normal, other.normal, t)!,
      normalOutline: Color.lerp(normalOutline, other.normalOutline, t)!,
      practice: Color.lerp(practice, other.practice, t)!,
      practiceOutline: Color.lerp(practiceOutline, other.practiceOutline, t)!,
    );
  }
}

@immutable
class BlabOnboardingTheme extends ThemeExtension<BlabOnboardingTheme> {
  const BlabOnboardingTheme({
    this.surface = OnboardingTheme.surface,
    this.ink = OnboardingTheme.ink,
    this.line = OnboardingTheme.line,
    this.error = OnboardingTheme.error,
    this.pressed = OnboardingTheme.actionPressed,
  });
  final Color surface, ink, line, error, pressed;
  static BlabOnboardingTheme of(BuildContext context) =>
      Theme.of(context).extension<BlabOnboardingTheme>() ??
      const BlabOnboardingTheme();
  @override
  BlabOnboardingTheme copyWith({
    Color? surface,
    Color? ink,
    Color? line,
    Color? error,
    Color? pressed,
  }) => BlabOnboardingTheme(
    surface: surface ?? this.surface,
    ink: ink ?? this.ink,
    line: line ?? this.line,
    error: error ?? this.error,
    pressed: pressed ?? this.pressed,
  );
  @override
  BlabOnboardingTheme lerp(covariant BlabOnboardingTheme? other, double t) {
    if (other == null) return this;
    return BlabOnboardingTheme(
      surface: Color.lerp(surface, other.surface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      line: Color.lerp(line, other.line, t)!,
      error: Color.lerp(error, other.error, t)!,
      pressed: Color.lerp(pressed, other.pressed, t)!,
    );
  }
}

@immutable
class BlabMediaTheme extends ThemeExtension<BlabMediaTheme> {
  const BlabMediaTheme({
    this.canvas = Colors.black,
    this.field = const Color(0xFF121A20),
    this.ink = Colors.white,
    this.muted = Colors.white70,
  });
  final Color canvas, field, ink, muted;
  static BlabMediaTheme of(BuildContext context) =>
      Theme.of(context).extension<BlabMediaTheme>() ?? const BlabMediaTheme();
  @override
  BlabMediaTheme copyWith({
    Color? canvas,
    Color? field,
    Color? ink,
    Color? muted,
  }) => BlabMediaTheme(
    canvas: canvas ?? this.canvas,
    field: field ?? this.field,
    ink: ink ?? this.ink,
    muted: muted ?? this.muted,
  );
  @override
  BlabMediaTheme lerp(covariant BlabMediaTheme? other, double t) {
    if (other == null) return this;
    return BlabMediaTheme(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      field: Color.lerp(field, other.field, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
    );
  }
}

@immutable
class BlabMotionTheme extends ThemeExtension<BlabMotionTheme> {
  const BlabMotionTheme({
    this.press = const Duration(milliseconds: 80),
    this.release = const Duration(milliseconds: 300),
  });
  final Duration press, release;
  static BlabMotionTheme of(BuildContext context) =>
      Theme.of(context).extension<BlabMotionTheme>() ?? const BlabMotionTheme();
  @override
  BlabMotionTheme copyWith({Duration? press, Duration? release}) =>
      BlabMotionTheme(
        press: press ?? this.press,
        release: release ?? this.release,
      );
  @override
  BlabMotionTheme lerp(covariant BlabMotionTheme? other, double t) {
    if (other == null) return this;
    Duration mix(Duration a, Duration b) => Duration(
      microseconds:
          (a.inMicroseconds + (b.inMicroseconds - a.inMicroseconds) * t)
              .round(),
    );
    return BlabMotionTheme(
      press: mix(press, other.press),
      release: mix(release, other.release),
    );
  }
}
