import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

enum InviteStatus { valid, expired, used }

class InviteLandingScreen extends ConsumerWidget {
  const InviteLandingScreen({
    super.key,
    required this.status,
    required this.inviterName,
    this.inviterLearningCode,
    this.token,
  });

  final InviteStatus status;
  final String inviterName;
  final String? inviterLearningCode;
  final String? token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: switch (status) {
            InviteStatus.valid => _ValidBody(
                inviterName: inviterName,
                token: token,
              ),
            InviteStatus.expired => _ExpiredBody(inviterName: inviterName),
            InviteStatus.used => _UsedBody(inviterName: inviterName),
          },
        ),
      ),
    );
  }
}

// ─────────────────────────── valid body ───────────────────────────────────

class _ValidBody extends StatelessWidget {
  const _ValidBody({
    required this.inviterName,
    required this.token,
  });

  final String inviterName;
  final String? token;

  void _onJoin(BuildContext context) {
    final params = StringBuffer('/invite/pick-language?inviter=$inviterName');
    if (token != null) params.write('&token=$token');
    context.push(params.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Center(
          child: Container(
            width: 88,
            height: 88,
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
                fontSize: 36,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          inviterName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: BlabColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'invited you to chat',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: BlabColors.textMuted,
            height: 1.4,
          ),
        ),
        const Spacer(),
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
            onPressed: () => _onJoin(context),
            child: Text(
              'Join $inviterName',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────── expired / used ───────────────────────────────

class _ExpiredBody extends StatelessWidget {
  const _ExpiredBody({required this.inviterName});

  final String inviterName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_off_outlined,
            size: 56,
            color: BlabColors.textMuted,
          ),
          const SizedBox(height: 18),
          const Text(
            'This invite expired.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: BlabColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask $inviterName for a fresh link.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: BlabColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsedBody extends StatelessWidget {
  const _UsedBody({required this.inviterName});

  final String inviterName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.link_off,
            size: 56,
            color: BlabColors.textMuted,
          ),
          const SizedBox(height: 18),
          const Text(
            'This invite was already claimed.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: BlabColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask $inviterName for a fresh link.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: BlabColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
