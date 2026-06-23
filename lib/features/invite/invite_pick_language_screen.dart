import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../shared/data/languages.dart';
import '../../shared/state/chat_list_state.dart';


class InvitePickLanguageScreen extends ConsumerStatefulWidget {
  const InvitePickLanguageScreen({
    super.key,
    required this.inviterName,
    this.token,
  });

  final String inviterName;
  final String? token;

  @override
  ConsumerState<InvitePickLanguageScreen> createState() =>
      _InvitePickLanguageScreenState();
}

class _InvitePickLanguageScreenState
    extends ConsumerState<InvitePickLanguageScreen> {
  BlabLanguage? _picked;
  bool _claiming = false;

  String get _ctaLabel => _picked == null
      ? 'Say hello'
      : 'Say ${_picked!.hello}';

  Future<void> _onContinue() async {
    final picked = _picked;
    if (picked == null) return;

    final token = widget.token;
    if (token == null) {
      context.push(
        '/auth?inviter=${widget.inviterName}&learn=${picked.code}',
      );
      return;
    }
    final signedIn =
        Supabase.instance.client.auth.currentSession != null;
    if (!signedIn) {
      showAppSnack('Sign in first, then tap the invite link again.');
      context.push('/auth?mode=signup');
      return;
    }
    setState(() => _claiming = true);
    try {
      final chatId = await ref
          .read(chatServiceProvider)
          .claimInvite(token: token, myLearningLanguage: picked.code);
      if (!mounted) return;
      await ref.read(chatListProvider.notifier).refresh();
      if (!mounted) return;
      context.go('/chat/$chatId');
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final msg = switch (e.message) {
        'invite_already_claimed' => 'This invite has already been used.',
        'invite_expired' => 'This invite has expired.',
        'invite_not_found' => "We couldn't find that invite.",
        'invite_self_claim' => "You can't accept your own invite.",
        _ => "Couldn't accept the invite. Try again."
      };
      showAppSnack(msg);
    } catch (_) {
      if (!mounted) return;
      showAppSnack("Couldn't accept the invite. Try again.");
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _picked != null && !_claiming;

    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      appBar: AppBar(
        backgroundColor: BlabColors.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: BlabColors.textPrimary,
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pick a language.',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: BlabColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We\'ll translate all messages into this language. Switch it whenever you like.',
                    style: TextStyle(
                      fontSize: 14,
                      color: BlabColors.textMuted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  children: [
                    for (var i = 0; i < kBlabLanguages.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      _LanguageRow(
                        lang: kBlabLanguages[i],
                        selected: kBlabLanguages[i].code == _picked?.code,
                        onTap: () =>
                            setState(() => _picked = kBlabLanguages[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: BlabColors.brand,
                    disabledBackgroundColor: const Color(0xFFC6C6C6),
                    disabledForegroundColor: const Color(0xFF707070),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: canContinue ? _onContinue : null,
                  child: _claiming
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _ctaLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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


class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.lang,
    required this.selected,
    required this.onTap,
  });

  final BlabLanguage lang;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected
              ? BlabColors.brand.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? BlabColors.brand : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: BlabColors.brand.withValues(alpha: 0.12),
            highlightColor: BlabColors.brand.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Text(
                lang.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? BlabColors.brand
                      : BlabColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
