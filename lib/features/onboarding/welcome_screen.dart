import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'onboarding_theme.dart';
import 'widgets/onboarding_scaffold.dart';
import 'widgets/onboarding_top_bar.dart';
import 'widgets/primary_action_button.dart';
import 'widgets/interface_language_menu.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    required this.interfaceLanguageCode,
    required this.onContinue,
    required this.onChangeInterfaceLanguage,
    super.key,
  });

  final String interfaceLanguageCode;
  final VoidCallback onContinue;
  final Future<void> Function(String languageCode) onChangeInterfaceLanguage;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return OnboardingScaffold(
      body: Column(
        children: [
          OnboardingTopBar(
            languageCode: interfaceLanguageCode,
            onLanguagePressed: () => _showLanguageMenu(context),
          ),
          Expanded(
            child: largeText
                ? SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(
                          height: 330,
                          child: _WelcomeIllustration(),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            OnboardingTheme.horizontalGutter + 2,
                            34,
                            OnboardingTheme.horizontalGutter + 2,
                            0,
                          ),
                          child: Text(
                            context.l10n.onboardingWelcomeTitle,
                            textAlign: TextAlign.center,
                            style: OnboardingTheme.headline.copyWith(
                              color: OnboardingTheme.warmInk,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            OnboardingTheme.horizontalGutter,
                            32,
                            OnboardingTheme.horizontalGutter,
                            18 + MediaQuery.paddingOf(context).bottom,
                          ),
                          child: PrimaryActionButton(
                            label: context.l10n.continueAction,
                            onPressed: onContinue,
                          ),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final illustrationHeight = (constraints.maxHeight * 0.53)
                          .clamp(330.0, 452.0);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: illustrationHeight,
                            child: const _WelcomeIllustration(),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              OnboardingTheme.horizontalGutter + 2,
                              34,
                              OnboardingTheme.horizontalGutter + 2,
                              0,
                            ),
                            child: Text(
                              context.l10n.onboardingWelcomeTitle,
                              textAlign: TextAlign.center,
                              style: OnboardingTheme.headline.copyWith(
                                color: OnboardingTheme.warmInk,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              OnboardingTheme.horizontalGutter,
                              20,
                              OnboardingTheme.horizontalGutter,
                              18 + MediaQuery.paddingOf(context).bottom,
                            ),
                            child: PrimaryActionButton(
                              label: context.l10n.continueAction,
                              onPressed: onContinue,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLanguageMenu(BuildContext context) async {
    final selected = await showInterfaceLanguageMenu(
      context,
      selectedCode: interfaceLanguageCode,
    );
    if (selected != null && context.mounted) {
      await onChangeInterfaceLanguage(selected);
    }
  }
}

class _WelcomeIllustration extends StatelessWidget {
  const _WelcomeIllustration();

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const _WelcomeIllustrationClipper(),
      child: Image.asset(
        'assets/onboarding/reading-nook.png',
        key: const Key('welcome-reading-nook-illustration'),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.none,
        excludeFromSemantics: true,
      ),
    );
  }
}

class _WelcomeIllustrationClipper extends CustomClipper<Path> {
  const _WelcomeIllustrationClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(0, size.height - 26)
      ..quadraticBezierTo(
        size.width * 0.56,
        size.height - 7,
        size.width,
        size.height - 58,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
