import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../shared/services/supabase_auth_service.dart';
import '../../shared/state/auth_state.dart';
import '../auth/widgets/blab_text_field.dart';
import '../auth/widgets/password_field.dart';

/// PRD US-035. Full-screen Delete-account page.
///
/// Same chassis as the rest of the Profile sub-pages (cream canvas,
/// transparent AppBar with ink back arrow + centered title). Promoted from
/// a bottom sheet because the action carries more information than a
/// simple confirm (what gets deleted, password / email confirmation, red
/// CTA + Cancel) — full-page treatment matches WhatsApp / Signal /
/// Telegram account-delete flows.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
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
    HapticFeedback.heavyImpact();
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
      // signOut already fires inside deleteAccount → the router redirect
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
        _err = "Couldn't delete your account. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(supabaseAuthServiceProvider);
    final usePassword = auth.hasPasswordIdentity;
    final email = auth.currentUser?.email ?? '';

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
          onPressed: _busy ? null : () => context.pop(),
        ),
        title: const Text(
          'Delete account',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: BlabColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'This is permanent. The following will be deleted:',
                  style: TextStyle(
                    fontSize: 13,
                    color: BlabColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _Card(
                children: const [
                  _DeleteRow(text: 'All chats and messages'),
                  _RowDivider(),
                  _DeleteRow(text: 'Your profile and photo'),
                  _RowDivider(),
                  _DeleteRow(text: 'Your settings and language picks'),
                ],
              ),
              const SizedBox(height: 22),
              if (usePassword)
                PasswordField(
                  controller: _password,
                  label: 'Confirm with password',
                  errorText: _err,
                  autofocus: true,
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
                  autofocus: true,
                  onChanged: (_) {
                    if (_err != null) setState(() => _err = null);
                  },
                ),
              const SizedBox(height: 24),
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
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white),
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
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: _busy ? null : () => context.pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BlabColors.textMuted,
                    ),
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

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 50),
      child: Container(height: 1, color: Colors.grey.shade100),
    );
  }
}

class _DeleteRow extends StatelessWidget {
  const _DeleteRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined,
              size: 20, color: Colors.orange.shade600),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: BlabColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
