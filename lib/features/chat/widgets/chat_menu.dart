part of '../chat_screen.dart';

/// Finite row width is essential: MenuAnchor measures children intrinsically,
/// and its overlay clipping alone does not make MenuItemButton text wrap.
double chatMenuWidth(BuildContext context) {
  final media = MediaQuery.of(context);
  return (media.size.width - media.padding.horizontal - 24).clamp(0.0, 440.0);
}

List<Widget> buildChatMenuEntries(
  BuildContext context, {
  required BlabLanguage learningLanguage,
  required VoidCallback onLearningLanguageTap,
  required VoidCallback onTranslationPreferencesTap,
}) {
  Widget entry(String label, VoidCallback onPressed, {String? value}) =>
      SizedBox(
        width: chatMenuWidth(context),
        child: MenuItemButton(
          onPressed: onPressed,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
            ),
            foregroundColor: const WidgetStatePropertyAll(
              BlabColors.sendButton,
            ),
          ),
          child: SizedBox(
            width: chatMenuWidth(context) - 32,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    label,
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: BlabColors.sendButton,
                    ),
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 2,
                    child: Text(
                      value,
                      softWrap: true,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: BlabColors.warmMuted,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 4),
                const BlabIcon(
                  name: 'nav-arrow-right - 20',
                  size: 20,
                  color: BlabColors.warmMuted,
                ),
              ],
            ),
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
