import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../shared/data/languages.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/widgets/picker_card.dart';


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
                    'Pick a language',
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < kBlabLanguages.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      languageCardEn(
                        kBlabLanguages[i],
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
              child: BrandButton(
                label: _ctaLabel,
                onPressed: canContinue ? _onContinue : null,
                loading: _claiming,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
