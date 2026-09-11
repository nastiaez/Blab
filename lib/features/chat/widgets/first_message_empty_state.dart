import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/models/chat.dart';

/// US-027.
class FirstMessageEmptyState extends StatelessWidget {
  const FirstMessageEmptyState({super.key, required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context) {
    if (chat.needsPracticeLanguageSelection) return const SizedBox.shrink();

    const lineStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: BlabColors.textPrimary,
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: BlabColors.phoneSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: BlabColors.divider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No messages here yet…',
                textAlign: TextAlign.center,
                style: lineStyle,
              ),
              const SizedBox(height: 14),
              const Text(
                'Send any message to start.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: BlabColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
