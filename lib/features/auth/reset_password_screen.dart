import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_messenger.dart';
import '../onboarding/onboarding_theme.dart';
import '../onboarding/widgets/onboarding_form_top_bar.dart';
import '../onboarding/widgets/onboarding_password_field.dart';
import '../onboarding/widgets/onboarding_scaffold.dart';
import '../onboarding/widgets/primary_action_button.dart';
import '../../l10n/l10n.dart';
import '../../shared/services/supabase_auth_service.dart';
import '../../shared/state/auth_state.dart';
import 'widgets/password_strength.dart';

/// PRD US-004 follow-through. Reached only via the recovery deep link
/// `blab://auth/reset?code=...`; the deep-link handler in main has
/// already called `getSessionFromUrl` to install a recovery session
/// before routing here, so we just need a new password.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pw = _password.text;
    final cf = _confirm.text;
    if (!meetsPasswordRequirement(pw)) {
      setState(() => _err = context.l10n.passwordMinLength);
      return;
    }
    if (pw != cf) {
      setState(() => _err = context.l10n.passwordsDoNotMatch);
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final auth = ref.read(supabaseAuthServiceProvider);
    try {
      await auth.updatePassword(pw);
      await auth.signOut();
      if (!mounted) return;
      context.go('/auth/login/email');
      showAppSuccessSnackAfterNavigation(context.l10n.passwordUpdated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = localizedAuthMessage(
          context.l10n,
          SupabaseAuthService.messageFor(e),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      body: Column(
        children: [
          OnboardingFormTopBar(
            title: context.l10n.setNewPassword,
            onBack: () => context.go('/auth/login'),
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
                  OnboardingPasswordField(
                    controller: _password,
                    label: context.l10n.newPassword,
                    errorText: _err,
                    enabled: !_busy,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      if (_err != null) setState(() => _err = null);
                      setState(() {});
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: PasswordGuidance(password: _password.text),
                  ),
                  const SizedBox(height: 16),
                  OnboardingPasswordField(
                    controller: _confirm,
                    label: context.l10n.confirmNewPassword,
                    enabled: !_busy,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _save(),
                    onChanged: (_) {
                      if (_err != null) setState(() => _err = null);
                    },
                  ),
                  const SizedBox(height: 24),
                  PrimaryActionButton(
                    label: context.l10n.saveNewPassword,
                    onPressed: _save,
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
