import 'package:flutter/material.dart';
import 'design_tokens.dart';
import 'material_theme_tokens.dart';
import 'blab_theme_extensions.dart';
export 'blab_theme_extensions.dart';
export 'design_tokens.dart';

final ThemeData blabTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  extensions: const [
    BlabComponentTheme(),
    BlabChatTheme(),
    BlabOnboardingTheme(),
    BlabMediaTheme(),
    BlabMotionTheme(),
  ],
  colorScheme: blabMaterialColorScheme,
  textTheme: blabMaterialTextTheme,
  pageTransitionsTheme: PageTransitionsTheme(
    builders: {
      ...const PageTransitionsTheme().builders,
      // Keep Flutter's native Android push/pop and predictive Back. Match the
      // transition's uncovered background to the app instead of flashing the
      // default white Material surface between warm-canvas pages.
      TargetPlatform.android: const PredictiveBackPageTransitionsBuilder(
        fallbackColor: BlabColors.appBackground,
      ),
    },
  ),
  scaffoldBackgroundColor: BlabColors.appBackground,
  appBarTheme: const AppBarThemeData(
    backgroundColor: BlabColors.appBackground,
    foregroundColor: BlabColors.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: BlabColors.chatCanvas,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    indicatorColor: Colors.transparent,
    height: 64,
    labelPadding: EdgeInsets.zero,
    labelTextStyle: WidgetStateProperty.resolveWith(
      (states) => TextStyle(
        fontSize: 11,
        height: 1.43,
        leadingDistribution: TextLeadingDistribution.even,
        letterSpacing: 0.25,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w600
            : FontWeight.w500,
        color: states.contains(WidgetState.selected)
            ? BlabColors.brand
            : BlabColors.textMuted,
      ),
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: const WidgetStatePropertyAll(Colors.white),
    trackColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.selected)
          ? BlabColors.brand
          : BlabColors.divider,
    ),
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    trackOutlineWidth: const WidgetStatePropertyAll(0),
  ),
  cardTheme: CardThemeData(
    color: BlabColors.chatSurface,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: BlabColors.chatDivider),
    ),
  ),
  // Preserve baseline native fallbacks; explicit warm/16-radius feature
  // variants still override these rather than retinting every existing modal.
  dialogTheme: DialogThemeData(
    backgroundColor: blabMaterialColorScheme.surfaceContainerHigh,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    elevation: 6,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
  ),
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: blabMaterialColorScheme.surfaceContainerLow,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
  ),
  dividerTheme: const DividerThemeData(
    color: BlabColors.chatDivider,
    thickness: 1,
    space: 1,
  ),
  // Transient feedback floats above bottom controls and dismisses by timeout,
  // swipe, action, or navigation. Close icons are reserved for persistent UI.
  snackBarTheme: const SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    showCloseIcon: false,
  ),
  // The approved orange pairs with dark warm ink for readable brand actions.
  filledButtonTheme: FilledButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.disabled)
            ? BlabColors.disabledOnSurface
            : BlabColors.warmInk;
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return BlabColors.warmInk.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.hovered)) {
          return BlabColors.warmInk.withValues(alpha: 0.06);
        }
        return Colors.transparent;
      }),
    ),
  ),
);
