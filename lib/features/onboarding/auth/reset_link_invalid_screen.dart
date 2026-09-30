import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/primary_action_button.dart';

class ResetLinkInvalidScreen extends StatelessWidget {
  const ResetLinkInvalidScreen({
    required this.onRequestNewLink,
    required this.onBackToLogin,
    super.key,
  });

  final VoidCallback onRequestNewLink;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final recoveryDetails = <Widget>[
      Image.asset(
        'assets/onboarding/mailbox-pixel-transparent.png',
        key: const Key('recovery-mailbox'),
        width: 210,
        height: 210,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        excludeFromSemantics: true,
      ),
      const SizedBox(height: 34),
      Text(
        context.l10n.resetLinkExpiredTitle,
        textAlign: TextAlign.center,
        style: OnboardingTheme.headline.copyWith(fontSize: 28),
      ),
      const SizedBox(height: 12),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Text(
          context.l10n.resetLinkExpiredBody,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: OnboardingTheme.muted,
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ),
    ];
    final actions = <Widget>[
      PrimaryActionButton(
        label: context.l10n.requestNewLink,
        onPressed: onRequestNewLink,
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: onBackToLogin,
        style: TextButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: OnboardingTheme.warmInk,
        ),
        child: Text(context.l10n.backToLogin),
      ),
    ];
    return OnboardingScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: OnboardingTheme.horizontalGutter,
          ),
          child: largeText
              ? SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: EdgeInsets.only(
                    top: 24,
                    bottom: 12 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    children: [
                      ...recoveryDetails,
                      const SizedBox(height: 32),
                      ...actions,
                    ],
                  ),
                )
              : Column(
                  children: [
                    const Spacer(flex: 3),
                    ...recoveryDetails,
                    const Spacer(flex: 4),
                    ...actions,
                    SizedBox(height: 12 + MediaQuery.paddingOf(context).bottom),
                  ],
                ),
        ),
      ),
    );
  }
}
