import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../shared/state/auth_state.dart';
import '../onboarding/onboarding_theme.dart';
import '../onboarding/widgets/onboarding_form_top_bar.dart';
import '../onboarding/widgets/onboarding_scaffold.dart';
import '../onboarding/widgets/primary_action_button.dart';

class ForgotPasswordSentScreen extends ConsumerStatefulWidget {
  const ForgotPasswordSentScreen({
    required this.email,
    this.onResend,
    this.onChangeEmail,
    this.onBackToLogin,
    super.key,
  });

  final String email;
  final Future<void> Function()? onResend;
  final VoidCallback? onChangeEmail;
  final VoidCallback? onBackToLogin;

  @override
  ConsumerState<ForgotPasswordSentScreen> createState() =>
      _ForgotPasswordSentScreenState();
}

class _ForgotPasswordSentScreenState
    extends ConsumerState<ForgotPasswordSentScreen> {
  Timer? _cooldownTimer;
  int _seconds = 0;
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_sending || _seconds > 0) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final action = widget.onResend;
      if (action != null) {
        await action();
      } else {
        await ref
            .read(supabaseAuthServiceProvider)
            .sendPasswordReset(widget.email);
      }
      if (!mounted) return;
      setState(() {
        _sent = true;
        _seconds = 30;
      });
      _cooldownTimer?.cancel();
      _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _seconds--);
        if (_seconds <= 0) timer.cancel();
      });
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final changeEmail =
        widget.onChangeEmail ??
        () => context.go(
          Uri(
            path: '/auth/forgot',
            queryParameters: {
              if (widget.email.isNotEmpty) 'email': widget.email,
            },
          ).toString(),
        );
    final backToLogin = widget.onBackToLogin ?? () => context.go('/auth/login');
    final recoveryDetails = <Widget>[
      Image.asset(
        'assets/onboarding/mailbox-pixel-transparent.png',
        key: const Key('recovery-mailbox'),
        width: 246,
        height: 242,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.none,
        excludeFromSemantics: true,
      ),
      const SizedBox(height: 24),
      Text(
        context.l10n.checkYourEmail,
        textAlign: TextAlign.center,
        style: OnboardingTheme.headline.copyWith(fontSize: 28),
      ),
      const SizedBox(height: 10),
      Text(
        context.l10n.resetLinkSent(widget.email),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: OnboardingTheme.muted,
          fontSize: 14,
          height: 1.45,
        ),
      ),
      const SizedBox(height: 18),
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            context.l10n.didntReceiveIt,
            textAlign: TextAlign.center,
            style: const TextStyle(color: OnboardingTheme.muted),
          ),
          TextButton(
            onPressed: _sending || _seconds > 0 ? null : _resend,
            child: Text(
              _sending
                  ? context.l10n.sending
                  : _seconds > 0
                  ? context.l10n.sendAgainIn(_seconds)
                  : _sent
                  ? context.l10n.emailSent
                  : context.l10n.sendAgain,
            ),
          ),
        ],
      ),
      if (_error != null)
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: OnboardingTheme.error, fontSize: 13),
        ),
      TextButton(onPressed: changeEmail, child: Text(context.l10n.changeEmail)),
    ];

    return OnboardingScaffold(
      body: Column(
        children: [
          OnboardingFormTopBar(title: '', onBack: changeEmail),
          Expanded(
            child: largeText
                ? SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      OnboardingTheme.horizontalGutter,
                      20,
                      OnboardingTheme.horizontalGutter,
                      18 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Column(
                      children: [
                        ...recoveryDetails,
                        const SizedBox(height: 28),
                        PrimaryActionButton(
                          label: context.l10n.backToLogin,
                          onPressed: backToLogin,
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: OnboardingTheme.horizontalGutter,
                    ),
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        ...recoveryDetails,
                        const Spacer(flex: 3),
                        PrimaryActionButton(
                          label: context.l10n.backToLogin,
                          onPressed: backToLogin,
                        ),
                        SizedBox(
                          height: 18 + MediaQuery.paddingOf(context).bottom,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
