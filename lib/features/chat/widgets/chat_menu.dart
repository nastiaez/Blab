part of '../chat_screen.dart';

List<Widget> buildChatMenuEntries(
  BuildContext context, {
  required BlabLanguage learningLanguage,
  required VoidCallback onLearningLanguageTap,
  required VoidCallback onTranslationPreferencesTap,
}) {
  Widget entry(String label, VoidCallback onPressed, {String? value}) =>
      MenuItemButton(
        onPressed: onPressed,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
          ),
          foregroundColor: const WidgetStatePropertyAll(BlabColors.sendButton),
        ),
        trailingIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null) ...[
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: BlabColors.warmMuted,
                ),
              ),
              const SizedBox(width: 4),
            ],
            const BlabIcon(
              name: 'nav-arrow-right - 20',
              size: 20,
              color: BlabColors.warmMuted,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: BlabColors.sendButton,
          ),
        ),
      );
  return [
    entry(
      context.l10n.learningLanguage,
      onLearningLanguageTap,
      value: localizedLanguageName(context.l10n, learningLanguage.code),
    ),
    const Divider(height: 1, color: BlabColors.chatDivider),
    entry(context.l10n.translationPreferences, onTranslationPreferencesTap),
  ];
}
