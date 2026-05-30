import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/services/supabase_auth_service.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/state/interface_language.dart';
import 'widgets/blab_text_field.dart';
import 'widgets/language_picker_sheet.dart';
import 'widgets/password_field.dart';
import 'widgets/password_strength.dart';
import 'widgets/sso_buttons.dart';

enum AuthMode { signUp, logIn }

/// Sign up / Log in screen. PRD US-001…US-005.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.initialMode = AuthMode.signUp});

  /// Which tab to land on. Defaults to [AuthMode.signUp]. Set to
  /// [AuthMode.logIn] when returning from the forgot-password flow so
  /// "Back to log in" actually returns to the log-in tab. PRD US-004.
  final AuthMode initialMode;

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

  final List<TapGestureRecognizer> _legalRecognizers = [];

  @override
  void initState() {
    super.initState();
    // Validate email on blur (PRD US-001). Fires whenever the field loses
    // focus, not only on Done/Enter.
    _emailFocus.addListener(() {
      if (!_emailFocus.hasFocus) {
        _validateEmail();
      }
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _emailFocus.dispose();
    for (final r in _legalRecognizers) {
      r.dispose();
    }
    super.dispose();
  }

  void _showLegalToast(String which) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$which (placeholder link)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(interfaceLanguageProvider);
    final isSignUp = _mode == AuthMode.signUp;

    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                language: lang,
                onTapLanguage: () async {
                  final picked = await showLanguagePickerSheet(context,
                      current: lang);
                  if (picked != null) {
                    ref.read(interfaceLanguageProvider.notifier).set(picked);
                  }
                },
              ),
              const SizedBox(height: 32),
              const Center(
                child: Text(
                  'Blab',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: BlabColors.brand,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Language exchange, real conversations',
                  style: TextStyle(fontSize: 13, color: BlabColors.textMuted),
                ),
              ),
              const SizedBox(height: 28),
              _ModeToggle(
                mode: _mode,
                onChanged: (m) => setState(() {
                  _mode = m;
                  _nameErr = null;
                  _emailErr = null;
                  _pwErr = null;
                }),
              ),
              const SizedBox(height: 22),
              SsoButtons(
                onPressed: (provider) => _socialSignIn(provider),
              ),
              const SizedBox(height: 18),
              const _OrDivider(),
              const SizedBox(height: 18),
              if (isSignUp) ...[
                BlabTextField(
                  controller: _name,
                  label: 'Name',
                  hint: 'Your first name',
                  errorText: _nameErr,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
              ],
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
              const SizedBox(height: 16),
              PasswordField(
                controller: _password,
                errorText: _pwErr,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.done,
              ),
              if (isSignUp) PasswordStrengthBar(password: _password.text),
              if (_formErr != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFF5C2C7)),
                  ),
                  child: Text(
                    _formErr!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFB42318),
                    ),
                  ),
                ),
              ],
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
                  onPressed: _busy ? null : _submit,
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
                      : Text(
                          isSignUp ? 'Create account  →' : 'Log in  →',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              if (isSignUp) ...[
                const SizedBox(height: 14),
                _LegalFinePrint(
                  onTermsTap: () => _showLegalToast('Terms'),
                  onPrivacyTap: () => _showLegalToast('Privacy Policy'),
                  recognizerSink: _legalRecognizers,
                ),
              ],
              if (!isSignUp) ...[
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: () => context.push('/auth/forgot'),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: BlabColors.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.language, required this.onTapLanguage});

  final dynamic language;
  final VoidCallback onTapLanguage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        InkWell(
          onTap: onTapLanguage,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                const Text('🌐', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Text(
                  language.code.toString().toUpperCase(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BlabColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final AuthMode mode;
  final ValueChanged<AuthMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _segment('Sign up', AuthMode.signUp),
          _segment('Log in', AuthMode.logIn),
        ],
      ),
    );
  }

  Widget _segment(String label, AuthMode m) {
    final selected = mode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: selected ? BlabColors.brand : BlabColors.textMuted,
            ),
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
    final line = Expanded(child: Container(height: 1, color: Colors.grey.shade300));
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or continue with email',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// PRD US-034: fine print under signup CTA with Terms + Privacy links.
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
