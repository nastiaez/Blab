import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../auth/widgets/password_field.dart';
import '../auth/widgets/password_strength.dart';

/// PRD US-012.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  String? _currentErr;
  String? _nextErr;
  String? _confirmErr;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentErr =
          _current.text.isEmpty ? 'Enter your current password' : null;
      _nextErr = _next.text.isEmpty
          ? 'Enter a new password'
          : (estimatePasswordStrength(_next.text).index <
                  PasswordStrength.fair.index
              ? 'Choose a stronger password'
              : null);
      _confirmErr = _confirm.text.isEmpty
          ? 'Confirm your new password'
          : (_confirm.text != _next.text ? "Passwords don't match" : null);
    });
    if (_currentErr == null && _nextErr == null && _confirmErr == null) {
      showAppSnack('Password updated ✓');
      context.pop();
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
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Change password',
          style: TextStyle(
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
              label: 'Current password',
              errorText: _currentErr,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.next,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            PasswordField(
              controller: _next,
              label: 'New password',
              errorText: _nextErr,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.next,
            ),
            PasswordStrengthBar(password: _next.text),
            const SizedBox(height: 16),
            PasswordField(
              controller: _confirm,
              label: 'Confirm new password',
              errorText: _confirmErr,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.done,
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
                onPressed: _submit,
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Center(
              child: TextButton(
                onPressed: () => context.push('/auth/forgot'),
                child: const Text(
                  'Forgot your password?',
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
    );
  }
}
