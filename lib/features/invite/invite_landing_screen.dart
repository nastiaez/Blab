import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/data/languages.dart';
import '../../shared/state/interface_language.dart';
import '../../shared/widgets/blab_icon.dart';
import '../auth/widgets/language_picker_sheet.dart';
import 'widgets/invite_progress_bar.dart';

enum InviteStatus { valid, expired, used }

/// Invite landing page. PRD US-024 (valid) + US-037 (expired / used).
///
/// Person-led hierarchy (Discord / Tandem pattern): tiny logo top, big
/// inviter avatar, personal headline. The invitee picks their own learning
/// language on the next step — the landing only displays the *inviter's*
/// learning language as context, never presets the invitee's.
class InviteLandingScreen extends ConsumerWidget {
  const InviteLandingScreen({
    super.key,
    required this.status,
    required this.inviterName,
    this.inviterLearningCode,
  });

  final InviteStatus status;
  final String inviterName;

  /// The language the *inviter* is learning. Shown in the headline copy as
  /// social context ("Nastia is learning Tamil."). Not a preset for the
  /// invitee — that's chosen on `/invite/pick-language`.
  final String? inviterLearningCode;

  BlabLanguage? get _inviterLearning {
    final code = inviterLearningCode;
    if (code == null) return null;
    for (final l in kBlabLanguages) {
      if (l.code == code) return l;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(interfaceLanguageProvider);

    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TopBar(
                code: lang.code.toUpperCase(),
                onTapLanguage: () async {
                  final picked = await showLanguagePickerSheet(
                    context,
                    current: lang,
                  );
                  if (picked != null) {
                    ref
                        .read(interfaceLanguageProvider.notifier)
                        .set(picked);
                  }
                },
              ),
              const SizedBox(height: 4),
              if (status == InviteStatus.valid) ...[
                const InviteProgressBar(current: 1),
                const SizedBox(height: 12),
              ],
              // Tiny wordmark — chrome only, person dominates below.
              Center(
                child: SvgPicture.asset(
                  'assets/blab-logo.svg',
                  height: 24,
                ),
              ),
              Expanded(
                child: switch (status) {
                  InviteStatus.valid => _ValidBody(
                      inviterName: inviterName,
                      inviterLearning: _inviterLearning,
                    ),
                  InviteStatus.expired =>
                    _ExpiredBody(inviterName: inviterName),
                  InviteStatus.used => const _UsedBody(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── top bar ──────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.code, required this.onTapLanguage});

  final String code;
  final VoidCallback onTapLanguage;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        InkWell(
          onTap: onTapLanguage,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                const BlabIcon(
                  name: 'globe',
                  size: 18,
                  color: BlabColors.textPrimary,
                ),
                const SizedBox(width: 6),
                Text(
                  code,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BlabColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── valid body ───────────────────────────────────

class _ValidBody extends ConsumerWidget {
  const _ValidBody({
    required this.inviterName,
    required this.inviterLearning,
  });

  final String inviterName;
  final BlabLanguage? inviterLearning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLanguage = inviterLearning != null;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              const SizedBox(height: 32),
              // Big inviter avatar — person dominates.
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BlabColors.avatarColorFor(inviterName),
                ),
                alignment: Alignment.center,
                child: Text(
                  inviterName.isNotEmpty
                      ? inviterName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 48,
                  ),
                ),
              ),
              const SizedBox(height: 26),
              if (hasLanguage)
                Text(
                  '$inviterName is learning ${inviterLearning!.name}.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: BlabColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              if (!hasLanguage)
                Text(
                  '$inviterName invited you to chat.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: BlabColors.textPrimary,
                    height: 1.3,
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                hasLanguage
                    ? "Chat with $inviterName in any language — you'll both pick up new words along the way."
                    : "Practice a new language by chatting with $inviterName.",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: BlabColors.textMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
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
              onPressed: () => context.push(
                '/invite/pick-language?inviter=$inviterName',
              ),
              child: const Text(
                'Start chatting',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── expired / used ───────────────────────────────

class _ExpiredBody extends StatelessWidget {
  const _ExpiredBody({required this.inviterName});

  final String inviterName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            const SizedBox(height: 60),
            const Icon(
              Icons.timer_off_outlined,
              size: 56,
              color: BlabColors.textMuted,
            ),
            const SizedBox(height: 18),
            const Text(
              'This invite has expired.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: BlabColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask $inviterName for a new link.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: BlabColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
        const _GetTheAppLink(),
      ],
    );
  }
}

class _UsedBody extends StatelessWidget {
  const _UsedBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: const [
        Column(
          children: [
            SizedBox(height: 60),
            Icon(
              Icons.link_off,
              size: 56,
              color: BlabColors.textMuted,
            ),
            SizedBox(height: 18),
            Text(
              'This invite has already been claimed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: BlabColors.textPrimary,
              ),
            ),
          ],
        ),
        _GetTheAppLink(),
      ],
    );
  }
}

class _GetTheAppLink extends StatelessWidget {
  const _GetTheAppLink();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('App download (placeholder)'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        child: const Text(
          'Get the app',
          style: TextStyle(
            fontSize: 14,
            color: BlabColors.brand,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: BlabColors.brand,
          ),
        ),
      ),
    );
  }
}
