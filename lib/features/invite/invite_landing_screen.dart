import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/data/languages.dart';
import 'widgets/exchange_card.dart';

enum InviteStatus { valid, expired, used }

/// Web-style invite landing page. Shown when someone opens an invite link.
///
/// PRD US-024 (valid state) + US-037 (expired / used).
class InviteLandingScreen extends StatelessWidget {
  const InviteLandingScreen({
    super.key,
    required this.status,
    required this.inviterName,
    required this.learnCode,
    required this.teachCode,
  });

  final InviteStatus status;
  final String inviterName;

  /// Language the invitee will learn (the inviter teaches it).
  final String learnCode;

  /// Language the invitee will teach (the inviter learns it).
  final String teachCode;

  BlabLanguage _lang(String code) => kBlabLanguages.firstWhere(
        (l) => l.code == code,
        orElse: () => kBlabLanguages.firstWhere((l) => l.code == 'en'),
      );

  @override
  Widget build(BuildContext context) {
    final learn = _lang(learnCode);
    final teach = _lang(teachCode);

    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Blab',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: BlabColors.brand,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'Language exchange, real conversations',
                  style: TextStyle(fontSize: 13, color: BlabColors.textMuted),
                ),
              ),
              const SizedBox(height: 40),
              if (status == InviteStatus.valid)
                _ValidBody(
                  inviterName: inviterName,
                  learn: learn,
                  teach: teach,
                  onAccept: () => context.push(
                    '/invite/signup?inviter=$inviterName'
                    '&learn=$learnCode&teach=$teachCode',
                  ),
                )
              else if (status == InviteStatus.expired)
                _ExpiredBody(inviterName: inviterName)
              else
                const _UsedBody(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValidBody extends StatelessWidget {
  const _ValidBody({
    required this.inviterName,
    required this.learn,
    required this.teach,
    required this.onAccept,
  });

  final String inviterName;
  final BlabLanguage learn;
  final BlabLanguage teach;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final brandBold = const TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: BlabColors.brand,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: BlabColors.textPrimary,
              height: 1.4,
            ),
            children: [
              TextSpan(text: inviterName, style: brandBold),
              const TextSpan(text: ' invited you to learn '),
              TextSpan(text: learn.name, style: brandBold),
              TextSpan(text: ' together ${learn.flag}'),
            ],
          ),
        ),
        const SizedBox(height: 32),
        ExchangeCard(
          topFlag: learn.flag,
          topLabel: 'She teaches you ${learn.name}',
          bottomFlag: teach.flag,
          bottomLabel: 'You teach her ${teach.name}',
        ),
        const SizedBox(height: 40),
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
            onPressed: onAccept,
            child: const Text(
              'Accept & join',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExpiredBody extends StatelessWidget {
  const _ExpiredBody({required this.inviterName});

  final String inviterName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.timer_off_outlined,
          size: 64,
          color: BlabColors.textMuted,
        ),
        const SizedBox(height: 20),
        const Text(
          'This invite has expired',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: BlabColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Ask $inviterName for a new link.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: BlabColors.textMuted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 40),
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
      children: const [
        Icon(
          Icons.link_off,
          size: 64,
          color: BlabColors.textMuted,
        ),
        SizedBox(height: 20),
        Text(
          'This invite has already been claimed',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: BlabColors.textPrimary,
          ),
        ),
        SizedBox(height: 40),
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
