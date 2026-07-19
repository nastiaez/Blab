import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/data/languages.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/widgets/picker_card.dart';
import 'invite_continuation.dart';

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

  String _ctaLabel(BuildContext context) => _picked == null
      ? context.l10n.sayHello
      : context.l10n.sayWord(_picked!.hello);

  Future<void> _onContinue() async {
    final picked = _picked;
    if (picked == null) return;

    final continuation = InviteContinuation(
      token: widget.token,
      inviterName: widget.inviterName,
      learningLanguage: picked.code,
    );
    final token = continuation.token;
    if (token == null) {
      context.push(continuation.authLocation());
      return;
    }
    final signedIn = ref.read(isSignedInProvider);
    if (!signedIn) {
      context.push(continuation.authLocation());
      return;
    }
    setState(() => _claiming = true);
    try {
      final chatId = await ref.read(inviteClaimActionProvider)(continuation);
      if (!mounted) return;
      context.go('/chat/$chatId');
    } catch (e) {
      if (!mounted) return;
      final failure = inviteClaimFailureFor(e);
      if (isTerminalInviteClaimFailure(failure)) {
        context.go(continuation.resolverLocation);
      } else {
        showAppSnack(localizedInviteClaimMessage(context.l10n, failure));
      }
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
          tooltip: context.l10n.back,
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
                  Text(
                    context.l10n.pickLanguage,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: BlabColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.pickLanguageHelp,
                    style: const TextStyle(
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
                label: _ctaLabel(context),
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
