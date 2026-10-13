/// Per-chat state adapter for the reusable Material mode control.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/chat.dart';
import '../state/chat_state.dart';
import 'word_popup.dart';
import 'chat_mode_toggle.dart';

const double kNormalModeToggleWidth = 129;
const double kPracticeModeToggleWidth = 129;

class ModeToggle extends ConsumerWidget {
  const ModeToggle({
    super.key,
    required this.chatId,
    this.onBeforeToggle,
    this.onModeChanged,
    this.enabled = true,
  });
  final String chatId;
  final bool enabled;
  final VoidCallback? onBeforeToggle;
  final ValueChanged<ChatMode>? onModeChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      BlabChatModeToggle.segmented(
        practice: ref.watch(chatModeProvider(chatId)) == ChatMode.practice,
        onChanged: enabled ? (_) => _toggle(context, ref) : null,
      );
  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    onBeforeToggle?.call();
    final current = ref.read(chatModeProvider(chatId));
    final next = current == ChatMode.practice
        ? ChatMode.normal
        : ChatMode.practice;
    ref.read(chatModeResetSignalProvider(chatId).notifier).bump();
    dismissWordPopup();
    await ref.read(chatModeProvider(chatId).notifier).set(next);
    onModeChanged?.call(next);
  }
}
