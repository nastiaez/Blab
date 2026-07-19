import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/data/invite_host.dart';
import '../../shared/data/languages.dart';
import 'widgets/share_invite_sheet.dart';

/// Shown when the **inviter** opens their own invite link (e.g. they
/// accidentally tap it in their own messenger thread). The body
/// depends on the invite's current state so the inviter sees something
/// useful instead of the recipient-facing landing.
class InviteOwnerScreen extends ConsumerWidget {
  const InviteOwnerScreen({
    super.key,
    required this.token,
    required this.inviterLearningCode,
    required this.expiresAt,
    required this.status,
    this.resultingChatId,
    this.claimedByName,
  });

  final String token;
  final String inviterLearningCode;
  final DateTime expiresAt;

  /// One of `valid`, `expired`, `used`.
  final String status;

  /// Populated when the invite was claimed — the chat that came out
  /// of it. Lets the claimed-self screen jump straight in.
  final String? resultingChatId;

  /// Display name of the person who accepted. Optional.
  final String? claimedByName;

  BlabLanguage? get _learning {
    for (final l in kBlabLanguages) {
      if (l.code == inviterLearningCode) return l;
    }
    return null;
  }

  String get _link => 'https://$kInviteHost/i/$token';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Widget body;
    switch (status) {
      case 'used':
        body = _ClaimedBody(
          chatId: resultingChatId,
          claimedByName: claimedByName,
        );
      case 'expired':
        body = const _ExpiredBody();
      default:
        body = _ValidBody(
          link: _link,
          learning: _learning,
          expiresAt: expiresAt,
        );
    }

    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: context.l10n.back,
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: BlabColors.textPrimary,
                    onPressed: () => context.go('/chats'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Center(
                child: SvgPicture.asset('assets/blab-logo.svg', height: 24),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Case 1: valid self-tap ─────────────────────────

class _ValidBody extends StatefulWidget {
  const _ValidBody({
    required this.link,
    required this.learning,
    required this.expiresAt,
  });

  final String link;
  final BlabLanguage? learning;
  final DateTime expiresAt;

  @override
  State<_ValidBody> createState() => _ValidBodyState();
}

class _ValidBodyState extends State<_ValidBody> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.link));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  Future<void> _share() async {
    await showShareInviteSheet(context, inviteLink: widget.link);
  }

  @override
  Widget build(BuildContext context) {
    final learn = widget.learning;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Text(
                context.l10n.inviteFriend,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: BlabColors.textPrimary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                learn != null
                    ? context.l10n.practicingLanguage(learn.name)
                    : context.l10n.shareYourInvite,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: BlabColors.textMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              InkWell(
                onTap: _copy,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: BlabColors.selectedTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.link,
                          style: const TextStyle(
                            fontSize: 13,
                            color: BlabColors.textPrimary,
                            height: 1.3,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _copied ? Icons.check : Icons.copy_outlined,
                        size: 18,
                        color: _copied
                            ? BlabColors.brand
                            : BlabColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.validUntil(
                  DateFormat.MMMEd(
                    Localizations.localeOf(context).toLanguageTag(),
                  ).add_Hm().format(widget.expiresAt),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: BlabColors.textMuted,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: BlabColors.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _share,
              icon: const Icon(
                Icons.share_outlined,
                size: 20,
                color: Colors.white,
              ),
              label: Text(
                context.l10n.shareInvite,
                style: const TextStyle(
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

// ───────────────────── Case 2: claimed self-tap ─────────────────────

class _ClaimedBody extends StatelessWidget {
  const _ClaimedBody({this.chatId, this.claimedByName});

  final String? chatId;
  final String? claimedByName;

  @override
  Widget build(BuildContext context) {
    final name = claimedByName?.trim() ?? '';
    final heading = name.isEmpty
        ? context.l10n.someoneJoined
        : context.l10n.personJoined(name);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              const SizedBox(height: 32),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: BlabColors.brand.withValues(alpha: 0.12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check_circle,
                  color: BlabColors.brand,
                  size: 40,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                heading,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: BlabColors.textPrimary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.alreadyConnected,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: BlabColors.textMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: BlabColors.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                if (chatId != null) {
                  context.go('/chat/$chatId');
                } else {
                  context.go('/chats');
                }
              },
              child: Text(
                chatId != null ? context.l10n.openChat : context.l10n.goToChats,
                style: const TextStyle(
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

// ──────────────────── Case 3: expired self-tap ────────────────────

class _ExpiredBody extends StatelessWidget {
  const _ExpiredBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              const SizedBox(height: 36),
              const Icon(
                Icons.timer_off_outlined,
                size: 56,
                color: BlabColors.textMuted,
              ),
              const SizedBox(height: 18),
              Text(
                context.l10n.yourInviteExpired,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: BlabColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.inviteExpiredHelp,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: BlabColors.textMuted,
                  height: 1.45,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: BlabColors.brand,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => context.go('/chats/new'),
              icon: const Icon(Icons.add, size: 20, color: Colors.white),
              label: Text(
                context.l10n.sendNewInvite,
                style: const TextStyle(
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
