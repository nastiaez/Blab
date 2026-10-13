import '../../shared/widgets/settings/blab_icon_label_row.dart';
import '../../shared/widgets/actions/blab_icon_button.dart';
import '../../shared/widgets/surfaces/blab_confirmation_dialog.dart';
import '../../shared/widgets/surfaces/blab_section_divider.dart';
import '../../shared/widgets/surfaces/blab_dialog.dart';
import '../../shared/widgets/navigation/blab_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/theme.dart';
import '../../shared/widgets/surfaces/blab_section_card.dart';
import '../../l10n/l10n.dart';
import '../../shared/services/local_account_data_store.dart';
import '../../shared/services/supabase_auth_service.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/state/interface_language.dart';
import '../../shared/state/privacy_settings.dart';
import '../chat/state/pending_sends_state.dart';

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
  String? _err;
  bool _busy = false;

  Future<void> _delete() async {
    HapticFeedback.heavyImpact();
    final auth = ref.read(supabaseAuthServiceProvider);

    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      await auth.deleteAccount(
        clearLocalData: const LocalAccountDataStore().clear,
      );
      ref.invalidate(typingIndicatorsProvider);
      ref.invalidate(readReceiptsProvider);
      ref.invalidate(interfaceLanguageProvider);
      ref.invalidate(pendingSendsProvider);
      // signOut already fires inside deleteAccount → the router redirect
      // listens to the auth-session stream and will bounce to /auth.
      // Don't pop or go() here — racing navigations crash Navigator.
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = localizedAuthMessage(
          context.l10n,
          SupabaseAuthService.messageFor(e),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _err = context.l10n.couldNotDeleteAccount;
      });
    }
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await _confirmDeleteAccount(context);
    if (confirmed == true && mounted) await _delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      appBar: BlabAppBar(
        backgroundColor: BlabColors.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: BlabIconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: BlabColors.textPrimary,
          onPressed: _busy ? null : () => context.pop(),
        ),
        title: Text(
          context.l10n.deleteAccount,
          style: const TextStyle(
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  context.l10n.deleteAccountPermanent,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BlabColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              BlabSectionCard(
                children: [
                  BlabIconLabelRow.accountWarning(
                    label: context.l10n.allChatsMessages,
                  ),
                  BlabSectionDivider(inset: 50, color: BlabColors.chatDivider),
                  BlabIconLabelRow.accountWarning(
                    label: context.l10n.yourProfile,
                  ),
                  BlabSectionDivider(inset: 50, color: BlabColors.chatDivider),
                  BlabIconLabelRow.accountWarning(
                    label: context.l10n.yourSettings,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              if (_err != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    _err!,
                    style: TextStyle(
                      fontSize: 14,
                      color: BlabColors.error,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: BlabColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _busy ? null : _confirmAndDelete,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          context.l10n.deleteForever,
                          style: const TextStyle(
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
                  child: Text(
                    context.l10n.cancel,
                    style: const TextStyle(
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

Future<bool?> _confirmDeleteAccount(BuildContext context) {
  return showBlabDialog<bool>(
    context: context,
    builder: (dialogContext) => BlabConfirmationDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        context.l10n.deleteAccountConfirmationTitle,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: Text(
        context.l10n.deleteAccountConfirmationBody,
        style: const TextStyle(
          fontSize: 14,
          color: BlabColors.textMuted,
          height: 1.4,
        ),
      ),
      actionsPadding: const EdgeInsets.only(right: 8, bottom: 8),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            context.l10n.cancel,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: BlabColors.textPrimary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            context.l10n.deleteForever,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: BlabColors.error,
            ),
          ),
        ),
      ],
    ),
  );
}
