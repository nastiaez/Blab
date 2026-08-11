/// PRD FR-23. Always-visible Normal/Practice segmented control at the top of
/// the chat. Replaces the old "Show translations and corrections" row in the
/// chat's ··· menu (Task 6) with a control the user sees without opening a
/// menu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/models/chat.dart';
import '../state/chat_state.dart';

class ModeToggle extends ConsumerWidget {
  const ModeToggle({super.key, required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(chatModeProvider(chatId));
    return Container(
      key: const ValueKey('mode-toggle'),
      decoration: BoxDecoration(
        color: BlabColors.selectedTint,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            label: context.l10n.normalMode,
            selected: mode == ChatMode.normal,
            onTap: () => _switchTo(context, ref, ChatMode.normal),
          ),
          _Segment(
            label: context.l10n.practiceMode,
            selected: mode == ChatMode.practice,
            onTap: () => _switchTo(context, ref, ChatMode.practice),
          ),
        ],
      ),
    );
  }

  Future<void> _switchTo(BuildContext context, WidgetRef ref, ChatMode next) async {
    final current = ref.read(chatModeProvider(chatId));
    if (current == next) return;
    ref.read(chatModeResetSignalProvider(chatId).notifier).bump();
    await ref.read(chatModeProvider(chatId).notifier).set(next);
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? BlabColors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : BlabColors.textMuted,
          ),
        ),
      ),
    );
  }
}
