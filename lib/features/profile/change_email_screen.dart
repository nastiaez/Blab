import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/services/supabase_auth_service.dart';
import '../../shared/state/auth_state.dart';
import '../auth/widgets/blab_text_field.dart';

/// PRD US-039. Lets a signed-in user change the email on their account.
/// Supabase sends a confirmation link to the new address; the email is
/// only switched after the user taps that link. Old email keeps working
/// until then.
class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  final _email = TextEditingController();
  String? _err;
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  bool _isValidEmail(String v) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim());

  Future<void> _send() async {
    final auth = ref.read(supabaseAuthServiceProvider);
    final current = auth.currentUser?.email?.trim().toLowerCase() ?? '';
    final next = _email.text.trim().toLowerCase();
    if (next.isEmpty) {
      setState(() => _err = 'Enter your new email');
      return;
    }
    if (!_isValidEmail(next)) {
      setState(() => _err = 'Enter a valid email address');
      return;
    }
    if (next == current) {
      setState(() => _err = 'That\'s already your email');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await auth.updateEmail(next);
      if (!mounted) return;
      setState(() {
        _sent = true;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = SupabaseAuthService.messageFor(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(supabaseAuthServiceProvider);
    final currentEmail = auth.currentUser?.email ?? '';
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
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Change email',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: BlabColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: _sent
              ? _SentBody(newEmail: _email.text.trim())
              : _FormBody(
                  currentEmail: currentEmail,
                  emailController: _email,
                  err: _err,
                  busy: _busy,
                  onChanged: () {
                    if (_err != null) setState(() => _err = null);
                  },
                  onSend: _send,
                ),
        ),
      ),
    );
  }
}

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.currentEmail,
    required this.emailController,
    required this.err,
    required this.busy,
    required this.onChanged,
    required this.onSend,
  });

  final String currentEmail;
  final TextEditingController emailController;
  final String? err;
  final bool busy;
  final VoidCallback onChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Current email',
          style: TextStyle(
              fontSize: 13,
              color: BlabColors.textMuted,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            currentEmail,
            style: const TextStyle(
                fontSize: 15,
                color: BlabColors.textPrimary,
                fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 20),
        BlabTextField(
          controller: emailController,
          label: 'New email',
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          errorText: err,
          autofocus: true,
          textInputAction: TextInputAction.send,
          onChanged: (_) => onChanged(),
        ),
        const SizedBox(height: 12),
        const Text(
          "We'll send a confirmation link to the new address. Your email only changes after you tap it. Old email keeps working until then.",
          style: TextStyle(fontSize: 13, color: BlabColors.textMuted),
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
            onPressed: busy ? null : onSend,
            child: busy
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
                    'Send confirmation',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SentBody extends StatelessWidget {
  const _SentBody({required this.newEmail});
  final String newEmail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text('📬', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 20),
          const Text(
            'Check your inbox',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            'We sent a confirmation link to\n$newEmail. Tap it to finish the change.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, color: BlabColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 28),
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
              onPressed: () => context.pop(),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
