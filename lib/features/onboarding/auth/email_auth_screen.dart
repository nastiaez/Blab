import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/services/supabase_auth_service.dart';
import '../../../shared/state/interface_language.dart';
import '../../auth/auth_screen.dart';
import '../../auth/widgets/password_strength.dart';
import '../onboarding_theme.dart';
import '../widgets/onboarding_password_field.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/onboarding_text_field.dart';
import '../widgets/onboarding_form_top_bar.dart';
import '../widgets/primary_action_button.dart';

class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({
    required this.mode,
    required this.onBack,
    required this.onAuthenticated,
    required this.onForgotPassword,
    required this.onExistingAccount,
    this.initialEmail,
    super.key,
  });

  final AuthMode mode;
  final VoidCallback onBack;
  final Future<void> Function() onAuthenticated;
  final ValueChanged<String> onForgotPassword;
  final ValueChanged<String> onExistingAccount;
  final String? initialEmail;

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail ?? '',
  );
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  String? _emailError;
  String? _passwordError;
  String? _formError;
  bool _existingAccount = false;
  bool _busy = false;
  bool _submittedOnce = false;

  bool get _isSignUp => widget.mode == AuthMode.signUp;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool _validEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());

  void _validate() {
    setState(() {
      _submittedOnce = true;
      _emailError = _email.text.trim().isEmpty
          ? context.l10n.enterEmail
          : (_validEmail(_email.text) ? null : context.l10n.enterValidEmail);
      _passwordError = _password.text.isEmpty
          ? context.l10n.enterPasswordToConfirm
          : (_isSignUp && !meetsPasswordRequirement(_password.text))
          ? context.l10n.passwordMinLength
          : null;
      _formError = null;
      _existingAccount = false;
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    _validate();
    if (_emailError != null || _passwordError != null) return;
    setState(() => _busy = true);
    try {
      await ref.read(emailAuthActionProvider)(
        EmailAuthRequest(
          mode: widget.mode,
          name: '',
          email: _email.text,
          password: _password.text,
          interfaceLanguage: ref.read(interfaceLanguageProvider).code,
        ),
      );
      if (mounted) await widget.onAuthenticated();
    } catch (error) {
      if (!mounted) return;
      final message = SupabaseAuthService.messageFor(error);
      setState(() {
        _existingAccount =
            message == 'An account with this email already exists';
        _formError = localizedAuthMessage(context.l10n, message);
      });
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
            onBack: widget.onBack,
            title: _isSignUp
                ? context.l10n.signUpWithEmail
                : context.l10n.logIn,
          ),
          Expanded(
            child: AutofillGroup(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  OnboardingTheme.horizontalGutter,
                  18,
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
                      errorText: _emailError,
                      enabled: !_busy,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      onSubmitted: (_) => _passwordFocus.requestFocus(),
                      onChanged: (value) {
                        if (_submittedOnce && _emailError != null) {
                          setState(() {
                            _emailError = _validEmail(value)
                                ? null
                                : context.l10n.enterValidEmail;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    OnboardingPasswordField(
                      controller: _password,
                      focusNode: _passwordFocus,
                      label: context.l10n.password,
                      errorText: _passwordError,
                      enabled: !_busy,
                      textInputAction: TextInputAction.done,
                      autofillHints: _isSignUp
                          ? const [AutofillHints.newPassword]
                          : const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      onChanged: (value) {
                        if (_submittedOnce && _passwordError != null) {
                          setState(() {
                            _passwordError = value.isEmpty
                                ? context.l10n.enterPasswordToConfirm
                                : (_isSignUp &&
                                      !meetsPasswordRequirement(value))
                                ? context.l10n.passwordMinLength
                                : null;
                          });
                        } else if (_isSignUp) {
                          setState(() {});
                        }
                      },
                    ),
                    if (_isSignUp)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: PasswordGuidance(password: _password.text),
                      )
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(
                              OnboardingTheme.minimumTapTarget,
                              OnboardingTheme.minimumTapTarget,
                            ),
                          ),
                          onPressed: _busy
                              ? null
                              : () =>
                                    widget.onForgotPassword(_email.text.trim()),
                          child: Text(
                            context.l10n.forgotPassword,
                            style: const TextStyle(
                              color: OnboardingTheme.warmInk,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    if (_formError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _formError!,
                        key: const Key('email-auth-form-error'),
                        style: const TextStyle(
                          color: OnboardingTheme.error,
                          fontSize: 13,
                        ),
                      ),
                      if (_existingAccount)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () =>
                                widget.onExistingAccount(_email.text.trim()),
                            child: Text(context.l10n.logIn),
                          ),
                        ),
                    ],
                    const SizedBox(height: 20),
                    PrimaryActionButton(
                      label: _isSignUp
                          ? context.l10n.createAccount
                          : context.l10n.logIn,
                      onPressed: _submit,
                      loading: _busy,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
