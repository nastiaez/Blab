part of '../chat_screen.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.hintText,
    required this.textLength,
    required this.maxLength,
    required this.counterShowAt,
    required this.isPractice,
    required this.enabled,
    required this.showTopBorder,
    required this.onAttach,
    required this.onSend,
    this.allowAttachment = true,
    this.autofocus = false,
    this.emojiPanelOpen = false,
    this.onToggleEmoji,
    this.onTapText,
    this.emojiPanel,
    this.bottomObstruction = 0,
    this.groupConversation = false,
    this.mentionPicker,
  });

  final bool groupConversation;
  final Widget? mentionPicker;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final String hintText;
  final int textLength;
  final int maxLength;
  final int counterShowAt;
  final bool isPractice;
  final bool enabled;
  final bool showTopBorder;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final bool allowAttachment;
  final bool autofocus;
  final bool emojiPanelOpen;
  final VoidCallback? onToggleEmoji, onTapText;
  final Widget? emojiPanel;
  final double bottomObstruction;

  @override
  Widget build(BuildContext context) {
    final overLimit = textLength > maxLength;
    final canSend = enabled && hasText && !overLimit;
    final showCounter = textLength >= counterShowAt;
    final atLimit = textLength >= maxLength;

    return Container(
      decoration: BoxDecoration(
        color: BlabColors.chatSurface,
        border: showTopBorder
            ? const Border(top: BorderSide(color: BlabColors.chatDivider))
            : null,
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?mentionPicker,
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                12,
                groupConversation ? 0 : 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Semantics(
                          label: context.l10n.message,
                          child: ChatComposerInput(
                            controller: controller,
                            focusNode: focusNode,
                            hintText: hintText,
                            groupConversation: groupConversation,
                            maxLength: maxLength,
                            enabled: enabled,
                            autofocus: autofocus,
                            emojiPanelOpen: emojiPanelOpen,
                            onToggleEmoji: onToggleEmoji,
                            onTapText: onTapText,
                            emojiTooltip: emojiPanelOpen
                                ? context.l10n.showKeyboard
                                : context.l10n.showEmoji,
                            attachTooltip: context.l10n.attach,
                            onAttach: onAttach,
                            showAttachment: allowAttachment,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ChatSendButton(
                        canSend: canSend,
                        groupConversation: groupConversation,
                        isPractice: isPractice,
                        tooltip: context.l10n.send,
                        onSend: onSend,
                      ),
                    ],
                  ),
                  if (showCounter)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 12, 0),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$textLength / $maxLength',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: atLimit
                                ? BlabColors.error
                                : BlabColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              key: const ValueKey('composer-input-obstruction'),
              height:
                  groupConversation &&
                      bottomObstruction <=
                          MediaQuery.viewPaddingOf(context).bottom
                  ? math.max(30.0, bottomObstruction)
                  : bottomObstruction,
              width: double.infinity,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: emojiPanel == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: emojiPanel,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── reply preview inside bubble ────────────────────
