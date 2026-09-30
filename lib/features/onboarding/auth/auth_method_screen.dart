import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/services/supabase_auth_service.dart';
import '../../auth/auth_screen.dart';
import '../onboarding_theme.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/onboarding_top_bar.dart';
import '../widgets/interface_language_menu.dart';
import '../widgets/auth_method_button.dart';

class AuthMethodScreen extends StatefulWidget {
  const AuthMethodScreen({
    required this.mode,
    required this.interfaceLanguageCode,
    required this.onBack,
    required this.onGoogle,
    required this.onEmail,
    required this.onSwitchMode,
    required this.onChangeInterfaceLanguage,
    required this.onTerms,
    required this.onPrivacy,
    super.key,
  });

  final AuthMode mode;
  final String interfaceLanguageCode;
  final VoidCallback onBack;
  final Future<void> Function() onGoogle;
  final VoidCallback onEmail;
  final VoidCallback onSwitchMode;
  final Future<void> Function(String languageCode) onChangeInterfaceLanguage;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  State<AuthMethodScreen> createState() => _AuthMethodScreenState();
}

class _AuthMethodScreenState extends State<AuthMethodScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _google() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onGoogle();
    } on SocialSignInCancelled {
      // Cancelling the native account picker is not an error.
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = widget.mode == AuthMode.signUp;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final methodControls = <Widget>[
      Text(
        isSignUp
            ? context.l10n.signupMethodTitle
            : context.l10n.loginMethodTitle,
        textAlign: TextAlign.center,
        style: OnboardingTheme.headline,
      ),
      const SizedBox(height: 52),
      AuthMethodButton(
        label: context.l10n.continueWithGoogle,
        leading: SvgPicture.asset(
          'assets/onboarding/google.svg',
          key: const Key('google-auth-icon'),
          width: 22,
          height: 22,
          excludeFromSemantics: true,
        ),
        loading: _busy,
        onPressed: _busy ? null : _google,
      ),
      const SizedBox(height: 12),
      AuthMethodButton(
        label: context.l10n.continueWithEmail,
        leading: SvgPicture.asset(
          'assets/onboarding/email.svg',
          key: const Key('email-auth-icon'),
          width: 22,
          height: 22,
          excludeFromSemantics: true,
        ),
        onPressed: _busy ? null : widget.onEmail,
      ),
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: OnboardingTheme.error, fontSize: 13),
        ),
      ],
      const SizedBox(height: 14),
      TextButton(
        onPressed: _busy ? null : widget.onSwitchMode,
        child: Text(
          isSignUp
              ? context.l10n.alreadyHaveAccount
              : context.l10n.dontHaveAccountSignUp,
          textAlign: TextAlign.center,
          style: const TextStyle(color: OnboardingTheme.warmInk, fontSize: 14),
        ),
      ),
    ];
    return OnboardingScaffold(
      body: Column(
        children: [
          OnboardingTopBar(
            languageCode: widget.interfaceLanguageCode,
            onBack: widget.onBack,
            onLanguagePressed: _changeLanguage,
          ),
          Expanded(
            child: largeText
                ? SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      OnboardingTheme.horizontalGutter,
                      40,
                      OnboardingTheme.horizontalGutter,
                      20 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ...methodControls,
                        if (isSignUp) ...[
                          const SizedBox(height: 40),
                          _LegalLinks(
                            onTerms: widget.onTerms,
                            onPrivacy: widget.onPrivacy,
                          ),
                        ],
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: OnboardingTheme.horizontalGutter,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(flex: 5),
                        ...methodControls,
                        const Spacer(flex: 4),
                        if (isSignUp)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: 20 + MediaQuery.paddingOf(context).bottom,
                            ),
                            child: _LegalLinks(
                              onTerms: widget.onTerms,
                              onPrivacy: widget.onPrivacy,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeLanguage() async {
    final selected = await showInterfaceLanguageMenu(
      context,
      selectedCode: widget.interfaceLanguageCode,
    );
    if (selected != null && mounted) {
      await widget.onChangeInterfaceLanguage(selected);
    }
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks({required this.onTerms, required this.onPrivacy});

  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    const plainStyle = TextStyle(
      color: OnboardingTheme.muted,
      fontSize: 12,
      height: 1.45,
    );
    const linkStyle = TextStyle(
      color: OnboardingTheme.muted,
      fontSize: 12,
      height: 1.45,
      decoration: TextDecoration.underline,
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(context.l10n.onboardingLegalPrefix, style: plainStyle),
        Semantics(
          link: true,
          child: GestureDetector(
            key: const Key('auth-terms-link'),
            onTap: onTerms,
            child: Text(context.l10n.onboardingLegalTerms, style: linkStyle),
          ),
        ),
        Text(context.l10n.onboardingLegalAnd, style: plainStyle),
        Semantics(
          link: true,
          child: GestureDetector(
            key: const Key('auth-privacy-link'),
            onTap: onPrivacy,
            child: Text(context.l10n.onboardingLegalPrivacy, style: linkStyle),
          ),
        ),
      ],
    );
  }
}
