import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/services/supabase_auth_service.dart';
import '../../shared/state/auth_state.dart';
import 'widgets/blab_text_field.dart';

/// PRD US-004.
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
    setState(() {
      _err = _email.text.trim().isEmpty
          ? 'Enter your email'
          : (_isValidEmail(_email.text) ? null : 'Enter a valid email address');
    });
    if (_err != null) return;
    setState(() => _busy = true);
    final auth = ref.read(supabaseAuthServiceProvider);
    try {
      await auth.sendPasswordReset(_email.text);
      if (!mounted) return;
      context.go(
          '/auth/forgot/sent?email=${Uri.encodeComponent(_email.text.trim())}');
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: BlabColors.textPrimary,
      ),
      backgroundColor: BlabColors.appBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Forgot your password?',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the email you signed up with and we\'ll send you a reset link.',
                style: TextStyle(fontSize: 14, color: BlabColors.textMuted),
              ),
              const SizedBox(height: 28),
              BlabTextField(
                controller: _email,
                label: 'Email',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                errorText: _err,
                autofocus: true,
                textInputAction: TextInputAction.send,
                // BUG-006: clear the stale "Enter a valid email" error as
                // soon as the user types something valid — don't make them
                // wait until the next submit.
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
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Send reset link  →',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: () => context.go('/auth?mode=login'),
                  child: const Text(
                    'Back to log in',
                    style: TextStyle(
                      color: BlabColors.brand,
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
