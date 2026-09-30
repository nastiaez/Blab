import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../onboarding_theme.dart';

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    required this.body,
    this.resizeToAvoidBottomInset = true,
    super.key,
  });

  final Widget body;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: OnboardingTheme.canvas,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: OnboardingTheme.canvas,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: OnboardingTheme.canvas,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: SafeArea(bottom: false, child: body),
      ),
    );
  }
}
