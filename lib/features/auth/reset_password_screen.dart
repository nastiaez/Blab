import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/services/supabase_auth_service.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/widgets/picker_card.dart';
import 'widgets/password_field.dart';
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
    final strength = estimatePasswordStrength(pw);
    if (pw.length < 6) {
      setState(() => _err = context.l10n.passwordMinLength);
      return;
    }
    if (strength == PasswordStrength.weak) {
      setState(() => _err = context.l10n.chooseStrongerPassword);
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
      if (!mounted) return;
      showAppSnack(context.l10n.passwordUpdated);
      context.go('/chats');
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
    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: BlabColors.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.setNewPassword,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.newPasswordHelp,
                style: const TextStyle(
                  fontSize: 14,
                  color: BlabColors.textMuted,
                ),
              ),
              const SizedBox(height: 28),
              PasswordField(
                controller: _password,
                label: context.l10n.newPassword,
                errorText: _err,
                onChanged: (_) {
                  if (_err != null) setState(() => _err = null);
                  setState(() {});
                },
              ),
              const SizedBox(height: 10),
              PasswordStrengthBar(password: _password.text),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirm,
                label: context.l10n.confirmNewPassword,
                onChanged: (_) {
                  if (_err != null) setState(() => _err = null);
                },
              ),
              const SizedBox(height: 24),
              BrandButton(
                label: context.l10n.saveNewPassword,
                onPressed: _save,
                loading: _busy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
