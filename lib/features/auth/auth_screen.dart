import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/data/legal_links.dart';
import '../../shared/services/supabase_auth_service.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/state/interface_language.dart';
import '../../shared/util/open_url.dart';
import '../../shared/widgets/blab_icon.dart';
import '../invite/widgets/invite_progress_bar.dart';
import 'widgets/blab_text_field.dart';
import 'widgets/language_picker_sheet.dart';
import 'widgets/password_field.dart';
import 'widgets/password_strength.dart';
import 'widgets/sso_buttons.dart';

enum AuthMode { signUp, logIn }

/// Sign up / Log in screen. PRD US-001…US-005.
///
/// Single-screen layout (Tandem/Bumble pattern): SSO buttons + email form
/// always visible together. Mode-switch link top-right slides the Name
/// field in/out and swaps the CTA copy.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.initialMode = AuthMode.signUp,
    this.inviterName,
    this.learnCode,
  });

  final AuthMode initialMode;

  /// When set, the screen is part of the invite flow. Top-left swaps the
  /// globe for a back arrow and the subtitle personalises the copy.
  final String? inviterName;

  /// Language code the invitee picked on the previous step. Backend wiring
  /// (Step 2.3) will use this when seeding the new chat row.
  final String? learnCode;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  late AuthMode _mode = widget.initialMode;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final FocusNode _emailFocus = FocusNode();

  String? _nameErr;
  String? _emailErr;
  String? _pwErr;
  String? _formErr;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) _validateEmail();
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
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

  Future<void> _socialSignIn(String provider) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _formErr = null;
    });
    final auth = ref.read(supabaseAuthServiceProvider);
    try {
      if (provider == 'google') {
        await auth.signInWithGoogle();
      } else {
        setState(() => _formErr = 'Apple sign-in coming soon');
        return;
      }
      if (!mounted) return;
      context.go('/chats');
    } on SocialSignInCancelled {
      // Silent — user dismissed picker.
    } catch (e) {
      if (!mounted) return;
      setState(() => _formErr = SupabaseAuthService.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _nameErr = (_mode == AuthMode.signUp && _name.text.trim().isEmpty)
          ? 'Enter your name'
          : null;
      _emailErr = _email.text.trim().isEmpty
          ? 'Enter your email'
          : (_isValidEmail(_email.text) ? null : 'Enter a valid email address');
      _pwErr = _password.text.isEmpty ? 'Enter your password' : null;
      _formErr = null;
    });
    if (_nameErr != null || _emailErr != null || _pwErr != null) return;

    setState(() => _busy = true);
    final auth = ref.read(supabaseAuthServiceProvider);
    try {
      if (_mode == AuthMode.signUp) {
        await auth.signUp(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
      }
      if (!mounted) return;
      context.go('/chats');
    } catch (e) {
      if (!mounted) return;
      setState(() => _formErr = SupabaseAuthService.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _switchMode() {
    setState(() {
      _mode = _mode == AuthMode.signUp ? AuthMode.logIn : AuthMode.signUp;
      _nameErr = null;
      _emailErr = null;
      _pwErr = null;
      _formErr = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(interfaceLanguageProvider);
    final isSignUp = _mode == AuthMode.signUp;

    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                code: lang.code.toUpperCase(),
                onTapLanguage: () async {
                  final picked = await showLanguagePickerSheet(context,
                      current: lang);
                  if (picked != null) {
                    ref.read(interfaceLanguageProvider.notifier).set(picked);
                  }
                },
                isSignUp: isSignUp,
                onTapSwitchMode: _switchMode,
                inviteFlow: widget.inviterName != null,
                onBack: () =>
                    context.canPop() ? context.pop() : context.go('/invite'),
              ),
              if (widget.inviterName != null) ...[
                const SizedBox(height: 8),
                const InviteProgressBar(current: 3),
              ],
              const SizedBox(height: 18),
              Center(
                child: SvgPicture.asset(
                  'assets/blab-logo.svg',
                  height: 44,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  widget.inviterName != null
                      ? 'Sign up to chat with ${widget.inviterName}.'
                      : 'Learn a language by chatting with a friend.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: BlabColors.textMuted,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SsoButtons(onPressed: _socialSignIn),
                      const SizedBox(height: 14),
                      const _OrDivider(),
                      const SizedBox(height: 14),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: isSignUp
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  BlabTextField(
                                    controller: _name,
                                    label: 'Name',
                                    hint: 'Your first name',
                                    errorText: _nameErr,
                                    textInputAction: TextInputAction.next,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                      BlabTextField(
                        controller: _email,
                        focusNode: _emailFocus,
                        label: 'Email',
                        hint: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailErr,
                        onEditingComplete: _validateEmail,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 12),
                      PasswordField(
                        controller: _password,
                        errorText: _pwErr,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.done,
                      ),
                      if (isSignUp)
                        PasswordStrengthBar(password: _password.text),
                      if (_formErr != null) ...[
                        const SizedBox(height: 10),
                        _InlineError(message: _formErr!),
                      ],
                      const SizedBox(height: 16),
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
                          onPressed: _busy ? null : _submit,
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
                              : Text(
                                  isSignUp ? 'Create account  →' : 'Log in  →',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      if (!isSignUp)
                        Center(
                          child: TextButton(
                            onPressed: () => context.push('/auth/forgot'),
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: BlabColors.brand,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      if (isSignUp) ...[
                        const SizedBox(height: 8),
                        _LegalFinePrint(
                          onTermsTap: () => openExternalUrl(kTermsUrl),
                          onPrivacyTap: () =>
                              openExternalUrl(kPrivacyPolicyUrl),
                        ),
                      ],
                    ],
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

// ─────────────────────────── top bar ──────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.code,
    required this.onTapLanguage,
    required this.isSignUp,
    required this.onTapSwitchMode,
    required this.inviteFlow,
    required this.onBack,
  });

  final String code;
  final VoidCallback onTapLanguage;
  final bool isSignUp;
  final VoidCallback onTapSwitchMode;

  /// When true, top-left swaps the globe for a back arrow (invite flow —
  /// language switcher lives on the invite landing instead).
  final bool inviteFlow;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final Widget leading = inviteFlow
        ? InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(Icons.arrow_back_ios_new,
                  size: 20, color: BlabColors.textPrimary),
            ),
          )
        : InkWell(
            onTap: onTapLanguage,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const BlabIcon(
                    name: 'globe',
                    size: 18,
                    color: BlabColors.textPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    code,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BlabColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        leading,
        InkWell(
          onTap: onTapSwitchMode,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              isSignUp ? 'Log in' : 'Sign up',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: BlabColors.brand,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── shared bits ──────────────────────────────────

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
        child: Container(height: 1, color: BlabColors.divider));
    return Row(
      children: [
        line,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or use email',
            style: TextStyle(fontSize: 12, color: BlabColors.textMuted),
          ),
        ),
        line,
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline,
            size: 16, color: BlabColors.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: BlabColors.error,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegalFinePrint extends StatefulWidget {
  const _LegalFinePrint({
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  State<_LegalFinePrint> createState() => _LegalFinePrintState();
}

class _LegalFinePrintState extends State<_LegalFinePrint> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = () => widget.onTermsTap();
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => widget.onPrivacyTap();
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      fontSize: 12,
      color: BlabColors.textMuted,
      height: 1.4,
    );
    const linkStyle = TextStyle(
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
              recognizer: _termsRecognizer,
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: linkStyle,
              recognizer: _privacyRecognizer,
            ),
            const TextSpan(text: ', and confirm you are at least 13.'),
          ],
        ),
      ),
    );
  }
}
