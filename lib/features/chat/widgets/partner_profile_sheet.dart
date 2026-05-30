import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../shared/models/chat.dart';
import '../../../shared/state/connectivity_state.dart';

/// Bottom sheet shown when the user taps the partner avatar / name in the
/// chat header. Read-only: shows who the partner is, what they speak
/// natively (= what you're learning) and what they're learning from you.
Future<void> showPartnerProfileSheet(
  BuildContext context, {
  required Chat chat,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _Body(chat: chat),
  );
}

class _Body extends ConsumerWidget {
  const _Body({required this.chat});
  final Chat chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncOnline = ref.watch(onlineProvider);
    final online = asyncOnline.maybeWhen(data: (v) => v, orElse: () => true);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Avatar
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                chat.partnerInitial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 36,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              chat.partnerName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: BlabColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            if (online)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF34C759),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 13,
                      color: BlabColors.textMuted,
                    ),
                  ),
                ],
              )
            else
              const Text(
                'Offline',
                style: TextStyle(fontSize: 13, color: BlabColors.textMuted),
              ),
            const SizedBox(height: 28),
            _Section(
              title: 'Languages',
              children: [
                _LangRow(
                  flag: chat.partnerNativeLanguage.flag,
                  text: 'Speaks ',
                  emphasis: chat.partnerNativeLanguage.name,
                  trailing: ' natively',
                ),
                _LangRow(
                  flag: chat.partnerLearningLanguage.flag,
                  text: 'Learning ',
                  emphasis: chat.partnerLearningLanguage.name,
                  trailing: ' with you',
                ),
              ],
            ),
            const SizedBox(height: 22),
            _Section(
              title: 'Chat',
              children: [
                Text(
                  _startedAgo(chat.startedAt ?? chat.timestamp),
                  style: const TextStyle(
                    fontSize: 14,
                    color: BlabColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _startedAgo(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'Started chatting just now';
    if (diff.inHours < 1) return 'Started chatting ${diff.inMinutes}m ago';
    if (diff.inDays < 1) return 'Started chatting ${diff.inHours}h ago';
    if (diff.inDays < 30) return 'Started chatting ${diff.inDays}d ago';
    final months = (diff.inDays / 30).floor();
    return 'Started chatting ${months}mo ago';
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: BlabColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          ...children
              .expand((c) => [c, const SizedBox(height: 8)])
              .toList()
            ..removeLast(),
        ],
      ),
    );
  }
}

class _LangRow extends StatelessWidget {
  const _LangRow({
    required this.flag,
    required this.text,
    required this.emphasis,
    required this.trailing,
  });

  final String flag;
  final String text;
  final String emphasis;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(flag, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: text,
                  style: const TextStyle(
                    fontSize: 15,
                    color: BlabColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: emphasis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: BlabColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: trailing,
                  style: const TextStyle(
                    fontSize: 15,
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
