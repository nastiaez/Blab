import 'package:flutter/material.dart';

import '../onboarding_theme.dart';

class OnboardingFormTopBar extends StatelessWidget {
  const OnboardingFormTopBar({
    required this.title,
    required this.onBack,
    this.centerTitle = false,
    super.key,
  });

  final String title;
  final VoidCallback onBack;
  final bool centerTitle;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final height = largeText ? 100.0 : 68.0;
    final maxTitleLines = largeText ? 2 : 1;
    if (centerTitle) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 8,
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
                icon: const Icon(Icons.chevron_left_rounded, size: 28),
                color: OnboardingTheme.warmInk,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64),
              child: Text(
                title,
                maxLines: maxTitleLines,
                overflow: largeText
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: OnboardingTheme.ink,
                  fontSize: 16,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      height: height,
      child: Row(
        children: [
          const SizedBox(width: 8),
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left_rounded, size: 28),
            color: OnboardingTheme.warmInk,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              title,
              maxLines: maxTitleLines,
              overflow: largeText
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: const TextStyle(
                color: OnboardingTheme.ink,
                fontSize: 16,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }
}
