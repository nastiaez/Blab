import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/l10n.dart';
import '../onboarding_theme.dart';

class OnboardingTopBar extends StatelessWidget {
  const OnboardingTopBar({
    required this.languageCode,
    required this.onLanguagePressed,
    this.onBack,
    super.key,
  });

  final String languageCode;
  final VoidCallback onLanguagePressed;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 68,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (onBack != null)
            Positioned(
              left: 12,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
                icon: const Icon(Icons.chevron_left_rounded, size: 26),
              ),
            ),
          SvgPicture.asset(
            'assets/onboarding/blab-logo-black.svg',
            width: 56,
            excludeFromSemantics: true,
          ),
          Positioned(
            right: 12,
            child: Semantics(
              button: true,
              label: context.l10n.interfaceLanguage,
              child: TextButton.icon(
                onPressed: onLanguagePressed,
                style: TextButton.styleFrom(
                  minimumSize: const Size(
                    OnboardingTheme.minimumTapTarget,
                    OnboardingTheme.minimumTapTarget,
                  ),
                  foregroundColor: OnboardingTheme.warmInk,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.language, size: 17),
                label: Text(
                  languageCode.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
