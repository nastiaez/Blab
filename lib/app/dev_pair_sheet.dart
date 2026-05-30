import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/widgets/blab_text_field.dart';
import '../features/auth/widgets/language_picker_sheet.dart';
import '../shared/data/languages.dart';
import '../shared/state/chat_list_state.dart';
import 'app_messenger.dart';
import 'theme.dart';

/// Dev-only sheet to pair two test accounts by email before the real
/// invite flow (Step 2.3) lands. Wraps the `pair_with_email` RPC. Task 9
/// of the chat-sync plan.
Future<void> showDevPairSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    isDismissible: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: const SafeArea(
          top: false,
          child: _DevPairSheetBody(),
        ),
      );
    },
  );
}

class _DevPairSheetBody extends ConsumerStatefulWidget {
  const _DevPairSheetBody();

  @override
  ConsumerState<_DevPairSheetBody> createState() => _DevPairSheetBodyState();
}

class _DevPairSheetBodyState extends ConsumerState<_DevPairSheetBody> {
  late final TextEditingController _emailCtrl;
  late BlabLanguage _myLearning;
  late BlabLanguage _partnerLearning;
  bool _busy = false;
  String? _emailError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController();
    final english = kBlabLanguages.firstWhere((l) => l.code == 'en');
    _myLearning = english;
    _partnerLearning = english;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMyLearning() async {
    final picked = await showLanguagePickerSheet(context, current: _myLearning);
    if (picked != null && mounted) {
      setState(() => _myLearning = picked);
    }
  }

  Future<void> _pickPartnerLearning() async {
    final picked =
        await showLanguagePickerSheet(context, current: _partnerLearning);
    if (picked != null && mounted) {
      setState(() => _partnerLearning = picked);
    }
  }

  String _mapError(Object e) {
    if (e is PostgrestException) {
      final m = e.message;
      if (m.contains('partner_not_found')) {
        return 'No account with that email.';
      }
      if (m.contains('cannot_pair_with_self')) {
        return "You can't pair with yourself.";
      }
      if (m.contains('not_signed_in')) {
        return 'Sign in first.';
      }
    }
    return 'Couldn\'t pair. Try again.';
  }

  Future<void> _onPair() async {
    final email = _emailCtrl.text.trim();
    setState(() {
      _emailError = null;
      _error = null;
    });

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _emailError = 'Enter a valid email.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(chatServiceProvider).pairWithEmail(
            partnerEmail: email,
            myLearning: _myLearning.code,
            partnerLearning: _partnerLearning.code,
          );
      // Refresh the chat list so the new tile appears immediately.
      // ignore: unawaited_futures
      ref.read(chatListProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnack('Paired ✓');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _mapError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Dev: pair with email',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: BlabColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'TEMP — real invites land in Step 2.3',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          BlabTextField(
            controller: _emailCtrl,
            label: 'Partner email',
            hint: 'name@example.com',
            keyboardType: TextInputType.emailAddress,
            errorText: _emailError,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
          _LanguageRow(
            label: 'I learn',
            lang: _myLearning,
            onTap: _busy ? null : _pickMyLearning,
          ),
          const SizedBox(height: 12),
          _LanguageRow(
            label: 'Partner learns',
            lang: _partnerLearning,
            onTap: _busy ? null : _pickPartnerLearning,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: BlabColors.brand,
                disabledBackgroundColor:
                    BlabColors.brand.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _busy ? null : _onPair,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Pair',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(fontSize: 13, color: Colors.red.shade600),
            ),
          ],
        ],
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.label,
    required this.lang,
    required this.onTap,
  });

  final String label;
  final BlabLanguage lang;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: BlabColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Text(lang.flag, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      lang.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: BlabColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: BlabColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
