import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/services/supabase_auth_service.dart';
import '../../shared/state/auth_state.dart';
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
  late final TextEditingController _email =
      TextEditingController(text: widget.prefilledEmail ?? '');
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
          ? 'Enter your email'
          : (_isValidEmail(_email.text)
              ? null
              : 'Enter a valid email address');
    });
    if (_err != null) return;
    setState(() => _busy = true);
    final auth = ref.read(supabaseAuthServiceProvider);
    try {
      await auth.sendPasswordReset(_email.text);
      if (!mounted) return;
      context.go(
        '/auth/forgot/sent?email=${Uri.encodeComponent(_email.text.trim())}',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = SupabaseAuthService.messageFor(e));
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
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/auth?mode=login'),
        ),
        title: const Text(
          'Forgot password?',
          style: TextStyle(
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
                label: 'Email',
                hint: 'you@example.com',
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
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: BlabColors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _busy ? null : _send,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        )
                      : const Text(
                          'Email me a reset link →',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
