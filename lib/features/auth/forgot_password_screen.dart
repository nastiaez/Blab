import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../onboarding/onboarding_theme.dart';
import '../onboarding/widgets/onboarding_form_top_bar.dart';
import '../onboarding/widgets/onboarding_scaffold.dart';
import '../onboarding/widgets/onboarding_text_field.dart';
import '../onboarding/widgets/primary_action_button.dart';
import '../../l10n/l10n.dart';
import '../../shared/services/supabase_auth_service.dart';
import '../../shared/state/auth_state.dart';

/// PRD US-004. Forgot-password page.
///
/// Same chassis as the Profile sub-pages (cream canvas, transparent AppBar
/// with centered title + ink back arrow, single primary CTA). No "Back to
/// log in" text button — the AppBar back already does that, and the
/// duplicate link was adding clutter under the CTA.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.prefilledEmail});

  final String? prefilledEmail;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  late final TextEditingController _email = TextEditingController(
    text: widget.prefilledEmail ?? '',
  );
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool _isValidEmail(String v) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim());

  Future<void> _send() async {
    HapticFeedback.mediumImpact();
    setState(() {
      _err = _email.text.trim().isEmpty
          ? context.l10n.enterEmail
          : (_isValidEmail(_email.text) ? null : context.l10n.enterValidEmail);
    });
    if (_err != null) return;
    setState(() => _busy = true);
    final auth = ref.read(supabaseAuthServiceProvider);
    try {
      await auth.sendPasswordReset(_email.text);
      if (!mounted) return;
      context.push(
        '/auth/forgot/sent?email=${Uri.encodeComponent(_email.text.trim())}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _err = localizedAuthMessage(
          context.l10n,
          SupabaseAuthService.messageFor(e),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      body: Column(
        children: [
          OnboardingFormTopBar(
            title: context.l10n.forgotPassword,
            onBack: () => context.canPop()
                ? context.pop()
                : context.go('/auth/login/email'),
          ),
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                OnboardingTheme.horizontalGutter,
                20,
                OnboardingTheme.horizontalGutter,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OnboardingTextField(
                    controller: _email,
                    label: context.l10n.email,
                    hintText: context.l10n.emailHint,
                    keyboardType: TextInputType.emailAddress,
                    errorText: _err,
                    textInputAction: TextInputAction.send,
                    autofillHints: const [AutofillHints.email],
                    enabled: !_busy,
                    onSubmitted: (_) => _send(),
                    onChanged: (value) {
                      if (_err != null && _isValidEmail(value)) {
                        setState(() => _err = null);
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  PrimaryActionButton(
                    label: context.l10n.emailResetLink,
                    onPressed: _send,
                    loading: _busy,
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
