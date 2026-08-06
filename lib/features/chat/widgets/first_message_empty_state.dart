import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/models/chat.dart';

/// Shown in a chat that has no messages yet: what you are learning here, plus a nudge
/// to send the first message. Plain text — no flags, card, or icons. Clears
/// as soon as a message is sent. US-026.
class FirstMessageEmptyState extends StatelessWidget {
  const FirstMessageEmptyState({super.key, required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context) {
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
              Text(
                context.l10n.youAreLearningLanguageWithPerson(
                  chat.learningLanguage.name,
                  chat.partnerName,
                ),
                textAlign: TextAlign.center,
                style: lineStyle,
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.sendAnyMessage,
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
