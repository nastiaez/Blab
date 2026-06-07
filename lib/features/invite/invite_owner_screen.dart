import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../shared/data/invite_host.dart';
import '../../shared/data/languages.dart';
import 'widgets/share_invite_sheet.dart';

/// Rendered when the inviter (the user who created the invite) opens
/// their own `https://blab-gray.vercel.app/i/<token>` link — usually
/// because they accidentally tapped it in their own messenger thread.
/// Instead of trying to claim it (which fails server-side with
/// `invite_self_claim`), the screen frames it as "this is yours" and
/// lets them re-share or copy the link.
class InviteOwnerScreen extends ConsumerStatefulWidget {
  const InviteOwnerScreen({
    super.key,
    required this.token,
    required this.inviterLearningCode,
    required this.expiresAt,
  });

  final String token;
  final String inviterLearningCode;
  final DateTime expiresAt;

  @override
  ConsumerState<InviteOwnerScreen> createState() => _InviteOwnerScreenState();
}

class _InviteOwnerScreenState extends ConsumerState<InviteOwnerScreen> {
  bool _copied = false;

  String get _link => 'https://$kInviteHost/i/${widget.token}';

  BlabLanguage? get _learning {
    for (final l in kBlabLanguages) {
      if (l.code == widget.inviterLearningCode) return l;
    }
    return null;
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _link));
    if (!mounted) return;
    setState(() => _copied = true);
  }

  Future<void> _shareAgain() async {
    await showShareInviteSheet(context, inviteLink: _link);
  }

  @override
  Widget build(BuildContext context) {
    final learning = _learning;
    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar mirrors the landing screen — back arrow only,
              // no globe (the inviter is already inside the app).
              Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon:
                        const Icon(Icons.arrow_back_ios_new, size: 20),
                    color: BlabColors.textPrimary,
                    onPressed: () => context.go('/chats'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Center(
                child: SvgPicture.asset(
                  'assets/blab-logo.svg',
                  height: 24,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 24),
                          const Text(
                            'Your invite link',
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
                            learning != null
                                ? 'You set this to learn ${learning.name} with whoever joins.'
                                : "You haven't set a learning language.",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: BlabColors.textMuted,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Link preview pill.
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: BlabColors.selectedTint,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _link,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: BlabColors.textPrimary,
                                      height: 1.3,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  _copied
                                      ? Icons.check
                                      : Icons.copy_outlined,
                                  size: 18,
                                  color: _copied
                                      ? BlabColors.brand
                                      : BlabColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Valid until ${_formatExpiry(widget.expiresAt)}.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: BlabColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 52,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: BlabColors.brand,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _copy,
                              icon: const Icon(Icons.copy_outlined,
                                  size: 20, color: Colors.white),
                              label: Text(
                                _copied ? 'Copied' : 'Copy link',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: BlabColors.textPrimary,
                                side: const BorderSide(
                                  color: BlabColors.divider,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: _shareAgain,
                              icon: const Icon(Icons.share_outlined,
                                  size: 18),
                              label: const Text(
                                'Share again',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatExpiry(DateTime d) {
  final w = _weekdays[(d.weekday - 1) % 7];
  final m = _months[d.month - 1];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$w, $m ${d.day} at $hh:$mm';
}
