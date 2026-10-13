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
  });

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

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
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
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + keyboardInset),
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
                        maxLength: maxLength,
                        enabled: enabled,
                        autofocus: autofocus,
                        attachTooltip: context.l10n.attach,
                        onAttach: onAttach,
                        showAttachment: allowAttachment,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChatSendButton(
                    canSend: canSend,
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
      ),
    );
  }
}

// ─────────────────────────── reply preview inside bubble ────────────────────
