import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/services/supabase_auth_service.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/widgets/picker_card.dart';
import 'widgets/blab_text_field.dart';

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
    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      appBar: AppBar(
        backgroundColor: BlabColors.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: BlabColors.textPrimary,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/auth?mode=login'),
        ),
        title: Text(
          context.l10n.forgotPassword,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: BlabColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BlabTextField(
                controller: _email,
                label: context.l10n.email,
                hint: context.l10n.emailHint,
                keyboardType: TextInputType.emailAddress,
                errorText: _err,
                autofocus: true,
                textInputAction: TextInputAction.send,
                onChanged: (v) {
                  if (_err != null && _isValidEmail(v)) {
                    setState(() => _err = null);
                  }
                },
              ),
              const SizedBox(height: 24),
              BrandButton(
                label: context.l10n.emailResetLink,
                onPressed: _send,
                loading: _busy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
