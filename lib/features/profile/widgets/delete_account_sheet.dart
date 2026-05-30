import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/theme.dart';
import '../../../shared/services/supabase_auth_service.dart';
import '../../../shared/state/auth_state.dart';
import '../../auth/widgets/blab_text_field.dart';
import '../../auth/widgets/password_field.dart';

/// PRD US-035: delete-account confirmation sheet.
Future<void> showDeleteAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: const _DeleteAccountBody(),
    ),
  );
}

class _DeleteAccountBody extends ConsumerStatefulWidget {
  const _DeleteAccountBody();

  @override
  ConsumerState<_DeleteAccountBody> createState() => _DeleteAccountBodyState();
}

class _DeleteAccountBodyState extends ConsumerState<_DeleteAccountBody> {
  final _password = TextEditingController();
  final _emailConfirm = TextEditingController();
  String? _err;
  bool _busy = false;

  @override
  void dispose() {
    _password.dispose();
    _emailConfirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final auth = ref.read(supabaseAuthServiceProvider);
    final usePassword = auth.hasPasswordIdentity;

    if (usePassword) {
      if (_password.text.isEmpty) {
        setState(() => _err = 'Enter your password to confirm');
        return;
      }
    } else {
      final currentEmail =
          auth.currentUser?.email?.trim().toLowerCase() ?? '';
      if (_emailConfirm.text.trim().toLowerCase() != currentEmail) {
        setState(() => _err = "That doesn't match your email");
        return;
      }
    }

    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      await auth.deleteAccount(
        password: usePassword ? _password.text : null,
      );
      // signOut already fired inside deleteAccount → the router redirect
      // listens to the auth-session stream and will bounce to /auth.
      // Don't pop or go() here — racing navigations crash Navigator.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = SupabaseAuthService.messageFor(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = 'Couldn\'t delete your account. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(supabaseAuthServiceProvider);
    final usePassword = auth.hasPasswordIdentity;
    final email = auth.currentUser?.email ?? '';
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Delete account?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: BlabColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This is permanent. The following will be deleted:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 14),
            const _DeleteBullet(text: 'All chats and messages'),
            const _DeleteBullet(text: 'Your profile and photo'),
            const _DeleteBullet(text: 'Your settings and language picks'),
            const SizedBox(height: 18),
            if (usePassword)
              PasswordField(
                controller: _password,
                label: 'Confirm with password',
                errorText: _err,
                onChanged: (_) {
                  if (_err != null) setState(() => _err = null);
                },
              )
            else
              BlabTextField(
                controller: _emailConfirm,
                label: 'Type $email to confirm',
                keyboardType: TextInputType.emailAddress,
                errorText: _err,
                onChanged: (_) {
                  if (_err != null) setState(() => _err = null);
                },
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade500,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _busy ? null : _delete,
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Delete forever',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: BlabColors.textPrimary,
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

class _DeleteBullet extends StatelessWidget {
  const _DeleteBullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_outlined,
              size: 18, color: Colors.orange.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: BlabColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
