import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../auth/widgets/blab_text_field.dart';
import '../auth/widgets/password_field.dart';
import '../auth/widgets/password_strength.dart';
import '../auth/widgets/sso_buttons.dart';

/// Invitee sign-up form. Same validation as the main auth screen, plus a
/// post-success in-app banner that mimics a push notification. PRD US-025.
class InviteeSignupScreen extends ConsumerStatefulWidget {
  const InviteeSignupScreen({super.key, required this.inviterName});

  final String inviterName;

  @override
  ConsumerState<InviteeSignupScreen> createState() =>
      _InviteeSignupScreenState();
}

class _InviteeSignupScreenState extends ConsumerState<InviteeSignupScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  String? _nameErr;
  String? _emailErr;
  String? _pwErr;

  final List<TapGestureRecognizer> _legalRecognizers = [];

  OverlayEntry? _bannerEntry;
  Timer? _bannerTimer;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    for (final r in _legalRecognizers) {
      r.dispose();
    }
    _bannerTimer?.cancel();
    _bannerEntry?.remove();
    super.dispose();
  }

  bool _isValidEmail(String v) {
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(v.trim());
  }

  void _validateEmail() {
    setState(() {
      _emailErr = _email.text.isEmpty || _isValidEmail(_email.text)
          ? null
          : 'Enter a valid email address';
    });
  }

  void _onSuccess() {
    _showJoinedBanner();
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _bannerEntry?.remove();
      _bannerEntry = null;
      context.go('/chats?as=aswin');
    });
  }

  void _showJoinedBanner() {
    _bannerEntry?.remove();
    final overlay = Overlay.of(context);
    _bannerEntry = OverlayEntry(
      builder: (_) => const _JoinedBanner(),
    );
    overlay.insert(_bannerEntry!);
  }

  void _submit() {
    setState(() {
      _nameErr = _name.text.trim().isEmpty ? 'Enter your name' : null;
      _emailErr = _email.text.trim().isEmpty
          ? 'Enter your email'
          : (_isValidEmail(_email.text) ? null : 'Enter a valid email address');
      _pwErr = _password.text.isEmpty ? 'Enter your password' : null;
    });
    if (_nameErr == null && _emailErr == null && _pwErr == null) {
      _onSuccess();
    }
  }

  void _showLegalToast(String which) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$which (placeholder link)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: BlabColors.brand,
          ),
          onPressed: () => context.canPop() ? context.pop() : context.go('/invite'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(
                child: Text(
                  'Blab',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: BlabColors.brand,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Sign up to start chatting with ${widget.inviterName}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: BlabColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 24),
              SsoButtons(
                onPressed: (_) => _onSuccess(),
              ),
              const SizedBox(height: 18),
              const _OrDivider(),
              const SizedBox(height: 18),
              BlabTextField(
                controller: _name,
                label: 'Name',
                hint: 'Your first name',
                errorText: _nameErr,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              BlabTextField(
                controller: _email,
                label: 'Email',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
                errorText: _emailErr,
                onEditingComplete: _validateEmail,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                errorText: _pwErr,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.done,
              ),
              PasswordStrengthBar(password: _password.text),
              const SizedBox(height: 22),
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
                  onPressed: _submit,
                  child: const Text(
                    'Create account  →',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _LegalFinePrint(
                onTermsTap: () => _showLegalToast('Terms'),
                onPrivacyTap: () => _showLegalToast('Privacy Policy'),
                recognizerSink: _legalRecognizers,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final line =
        Expanded(child: Container(height: 1, color: Colors.grey.shade300));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or continue with email',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ),
        line,
      ],
    );
  }
}

class _LegalFinePrint extends StatelessWidget {
  const _LegalFinePrint({
    required this.onTermsTap,
    required this.onPrivacyTap,
    required this.recognizerSink,
  });

  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;
  final List<TapGestureRecognizer> recognizerSink;

  @override
  Widget build(BuildContext context) {
    final termsRecognizer = TapGestureRecognizer()..onTap = onTermsTap;
    final privacyRecognizer = TapGestureRecognizer()..onTap = onPrivacyTap;
    recognizerSink
      ..add(termsRecognizer)
      ..add(privacyRecognizer);

    const baseStyle = TextStyle(
      fontSize: 12,
      color: BlabColors.textMuted,
      height: 1.4,
    );
    final linkStyle = TextStyle(
      fontSize: 12,
      color: BlabColors.brand,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: BlabColors.brand,
      height: 1.4,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: baseStyle,
          children: [
            const TextSpan(text: 'By creating an account you agree to our '),
            TextSpan(
              text: 'Terms',
              style: linkStyle,
              recognizer: termsRecognizer,
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: linkStyle,
              recognizer: privacyRecognizer,
            ),
            const TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }
}

/// Slide-down "push-style" banner shown on successful signup. Mounted into the
/// root `Overlay` so it sits above the Scaffold and survives the upcoming
/// navigation.
class _JoinedBanner extends StatefulWidget {
  const _JoinedBanner();

  @override
  State<_JoinedBanner> createState() => _JoinedBannerState();
}

class _JoinedBannerState extends State<_JoinedBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, -1.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Positioned(
      top: topInset + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _offset,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: BlabColors.brand,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'B',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: BlabColors.textPrimary,
                        height: 1.3,
                      ),
                      children: [
                        TextSpan(
                          text: 'Aswin joined!',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: '  Start chatting.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
