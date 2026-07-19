import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/services/supabase_auth_service.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/widgets/picker_card.dart';
import '../auth/widgets/password_field.dart';
import '../auth/widgets/password_strength.dart';

/// PRD US-012.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  String? _currentErr;
  String? _nextErr;
  String? _confirmErr;
  String? _formErr;
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    HapticFeedback.mediumImpact();
    final current = _current.text;
    final next = _next.text;
    final confirm = _confirm.text;
    setState(() {
      _formErr = null;
      _currentErr = current.isEmpty ? context.l10n.enterCurrentPassword : null;
      _nextErr = _validateNewPassword(current: current, next: next);
      _confirmErr = confirm.isEmpty
          ? context.l10n.confirmPassword
          : (confirm != next ? context.l10n.passwordsDoNotMatch : null);
    });
    if (_currentErr != null || _nextErr != null || _confirmErr != null) return;

    setState(() => _busy = true);
    try {
      await ref.read(changePasswordActionProvider)(
        currentPassword: current,
        newPassword: next,
      );
      if (!mounted) return;
      showAppSnack(context.l10n.passwordUpdated);
      context.go('/profile');
    } catch (error) {
      if (!mounted) return;
      final message = localizedAuthMessage(
        context.l10n,
        SupabaseAuthService.passwordChangeMessageFor(error),
      );
      setState(() {
        _busy = false;
        if (message == context.l10n.currentPasswordIncorrect) {
          _currentErr = message;
        } else {
          _formErr = message;
        }
      });
    }
  }

  String? _validateNewPassword({
    required String current,
    required String next,
  }) {
    if (next.isEmpty) return context.l10n.enterNewPassword;
    if (next.length < 6) return context.l10n.passwordMinLength;
    if (next == current) return context.l10n.chooseDifferentPassword;
    if (estimatePasswordStrength(next).index < PasswordStrength.fair.index) {
      return context.l10n.chooseStrongerPassword;
    }
    return null;
  }

  void _clearErrors() {
    if (_currentErr == null &&
        _nextErr == null &&
        _confirmErr == null &&
        _formErr == null) {
      return;
    }
    setState(() {
      _currentErr = null;
      _nextErr = null;
      _confirmErr = null;
      _formErr = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPasswordIdentity = ref.watch(hasPasswordIdentityProvider);
    if (!hasPasswordIdentity) {
      return Scaffold(
        backgroundColor: BlabColors.appBackground,
        appBar: AppBar(
          backgroundColor: BlabColors.appBackground,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => context.go('/profile'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.l10n.passwordSignInUnavailable,
              textAlign: TextAlign.center,
              style: TextStyle(color: BlabColors.textMuted),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        backgroundColor: BlabColors.appBackground,
        appBar: AppBar(
          backgroundColor: BlabColors.appBackground,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: BlabColors.textPrimary,
            onPressed: _busy ? null : () => context.pop(),
          ),
          title: Text(
            context.l10n.changePassword,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: BlabColors.textPrimary,
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PasswordField(
                controller: _current,
                label: context.l10n.currentPassword,
                errorText: _currentErr,
                onChanged: (_) => _clearErrors(),
                textInputAction: TextInputAction.next,
                autofocus: true,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _busy ? null : () => context.push('/auth/forgot'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                  ),
                  child: Text(
                    context.l10n.forgotYourPassword,
                    style: const TextStyle(
                      color: BlabColors.brand,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PasswordField(
                controller: _next,
                label: context.l10n.newPassword,
                errorText: _nextErr,
                onChanged: (_) {
                  _clearErrors();
                  setState(() {});
                },
                textInputAction: TextInputAction.next,
              ),
              PasswordStrengthBar(password: _next.text),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirm,
                label: context.l10n.confirmNewPassword,
                errorText: _confirmErr,
                onChanged: (_) => _clearErrors(),
                textInputAction: TextInputAction.done,
              ),
              if (_formErr != null) ...[
                const SizedBox(height: 10),
                Text(
                  _formErr!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              BrandButton(
                label: context.l10n.save,
                onPressed: _busy ? null : _submit,
                loading: _busy,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
