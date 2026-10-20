part of '../chat_screen.dart';

class ChatMessageRow extends ConsumerWidget {
  const ChatMessageRow({
    super.key,
    this.highlighted = false,
    required this.chatId,
    required this.partnerName,
    required this.message,
    required this.reactions,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.languageCode,
    required this.replyLanguageCode,
    required this.translationInterfaceLanguageCode,
    required this.shouldTranslate,
    required this.practiceSetupRequired,
    required this.translationCutoffAt,
    required this.popupTopInset,
    required this.deferTranslationResolve,
    required this.onLongPress,
    required this.onReply,
    required this.onJumpToMessage,
    required this.onFailedTap,
    required this.onFailedRetry,
    required this.onReact,
    this.onDoubleTapHeart,
    required this.isSelected,
    required this.showOriginal,
    this.selectedBubbleKey,
  });

  final bool highlighted;
  final String chatId;
  final String partnerName;
  final Message message;
  final List<MessageReactionSummary> reactions;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final String languageCode;
  final String replyLanguageCode;

  /// The reader's primary known language — the translation pipeline's
  /// "interface" slot (cache-row key, second-lane target). See
  /// [ChatTimeline.translationInterfaceLanguageCode].
  final String translationInterfaceLanguageCode;
  final bool shouldTranslate;
  final bool practiceSetupRequired;
  final DateTime? translationCutoffAt;
  final double popupTopInset;
  final bool deferTranslationResolve;
  final void Function(Rect bubbleRect, Offset pressPosition) onLongPress;
  final VoidCallback onReply;
  final void Function(Message) onJumpToMessage;
  final VoidCallback onFailedTap;
  final VoidCallback onFailedRetry;
  final VoidCallback onReact;
  final VoidCallback? onDoubleTapHeart;
  final bool isSelected;
  final bool showOriginal;
  final GlobalKey? selectedBubbleKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOut = message.isOutgoing;
    final topGap = isFirstInGroup ? 10.0 : 2.0;
    final width = MediaQuery.sizeOf(context).width;
    final maxBubble = width * (isOut ? 0.78 : 0.72);
    final isFailed = message.status == MessageStatus.failed;
    final replyTo = message.replyTo;

    // FR-23 / modes-known-languages spec: practice mode always targets the
    // chat's learning language; normal mode targets the reader's primary
    // known language. Stays '' (never a supported-language match below)
    // until knownLanguagesProvider resolves, so no translation is requested
    // against a guessed target in the meantime (finding: a normal-mode chat
    // was briefly firing requests at the *learning* language before this).
    final mode = ref.watch(chatModeProvider(chatId));
    final knownLanguages = ref.watch(knownLanguagesProvider).value;
    final targetLang = knownLanguages == null
        ? ''
        : resolveTranslationTarget(
            mode: mode,
            learningLanguageCode: languageCode,
            primaryKnownLanguageCode: knownLanguages.primary,
          );
    final replyTargetLang = knownLanguages == null
        ? ''
        : resolveTranslationTarget(
            mode: mode,
            learningLanguageCode: replyLanguageCode,
            primaryKnownLanguageCode: knownLanguages.primary,
          );
    final knownLanguageCodes = knownLanguages?.codes ?? [languageCode];

    final deliveryAllowsLanguageAid =
        !isOut ||
        message.status == MessageStatus.delivered ||
        message.status == MessageStatus.read;
    final canRequestTranslation =
        deliveryAllowsLanguageAid &&
        shouldTranslate &&
        shouldRequestTranslation(
          targetLanguageCode: targetLang,
          text: message.originalText,
          sentAt: message.sentAt,
          translationCutoffAt: translationCutoffAt,
        );
    final canRequestReplyTranslation =
        !practiceSetupRequired &&
        replyTo != null &&
        shouldRequestBubbleTranslation(
          targetLanguageCode: replyTargetLang,
          text: replyTo.originalText,
          sentAt: replyTo.sentAt,
          translationCutoffAt: null,
        );
    final translationNotifier =
        canRequestTranslation || canRequestReplyTranslation
        ? ref.read(messageTranslationsProvider(chatId).notifier)
        : null;
    final translationEntry =
        canRequestTranslation &&
            kSupportedLearningLanguages.contains(targetLang)
        ? ref.read(messageTranslationsProvider(chatId))[translationEntryKey(
            message.id,
            targetLang,
            translationInterfaceLanguageCode,
          )]
        : null;
    final readableForRead =
        mode == ChatMode.normal ||
        isOut ||
        !canRequestTranslation ||
        translationEntry is AsyncData<MessageTranslation> ||
        translationEntry is AsyncError<MessageTranslation>;
    final readsNotifier = !isOut
        ? ref.read(messageReadsProvider(chatId).notifier)
        : null;

    // MessageInteractionTarget (long-press / swipe-reply gesture surface) is
    // wired here but applied inside MessageBubble, around the bubble content only
    // — never around the practice-mode translate icon beside it. It measures
    // its own RenderBox to position the floating reaction row
    // (_selectedBubbleRect), so if it wrapped the icon+bubble Row too, that
    // rect would include the icon and throw off the row's horizontal
    // centering on every practice-mode long-press.
    Widget bubble = MessageBubble(
      onJumpToMessage: onJumpToMessage,
      chatId: chatId,
      partnerName: partnerName,
      message: message,
      maxWidth: maxBubble,
      isLastInGroup: isLastInGroup,
      languageCode: languageCode,
      targetLanguageCode: targetLang,
      replyTargetLanguageCode: replyTargetLang,
      translationInterfaceLanguageCode: translationInterfaceLanguageCode,
      mode: mode,
      knownLanguageCodes: knownLanguageCodes,
      shouldTranslate: canRequestTranslation,
      replyToShouldTranslate: canRequestReplyTranslation,
      popupTopInset: popupTopInset,
      deferTranslationResolve: deferTranslationResolve,
      reactions: reactions,
      onReact: onReact,
      onDoubleTapHeart: onDoubleTapHeart,
      isFailed: isFailed,
      onLongPress: onLongPress,
      onFailedTap: onFailedTap,
      onFailedRetry: onFailedRetry,
      onSwipeReply: canReplyToMessage(message) ? onReply : null,
      selectedBubbleKey: selectedBubbleKey,
      isSelected: isSelected,
      showOriginal: showOriginal,
    );

    // Cache hydration happens by loaded page, but a live LLM request starts
    // only when the bubble actually enters the viewport. The same visibility
    // callback retains incoming read-receipt behavior.
    if (canRequestTranslation || canRequestReplyTranslation || !isOut) {
      bubble = VisibilityDetector(
        key: Key('msg-vis-${message.id}'),
        onVisibilityChanged: (info) {
          if (canRequestTranslation && info.visibleFraction > 0) {
            translationNotifier!.ensureVisible(
              visibleFraction: info.visibleFraction,
              messageId: message.id,
              text: message.originalText,
              targetLang: targetLang,
              interfaceLang: translationInterfaceLanguageCode,
              priority: message.type == MessageType.image,
            );
          }
          if (canRequestReplyTranslation && info.visibleFraction > 0) {
            translationNotifier!.ensureVisible(
              visibleFraction: info.visibleFraction,
              messageId: replyTo.id,
              text: replyTo.originalText,
              targetLang: replyTargetLang,
              interfaceLang: translationInterfaceLanguageCode,
            );
          }
          // Threshold lowered to 0.5 so partially-visible bubbles still
          // register — bottom-of-list messages were sometimes cropped by
          // the input bar and never crossed 0.9.
          if (!practiceSetupRequired &&
              !isOut &&
              readableForRead &&
              info.visibleFraction > 0.5) {
            readsNotifier!.reportVisible(message.id);
          }
        },
        child: bubble,
      );
    }

    return MessageRowReplyTarget(
      key: ValueKey('message-row-reply-${message.id}'),
      onSwipeReply: canReplyToMessage(message) ? onReply : null,
      child: Padding(
        // Keep the same 12px breathing room on both physical edges. Outgoing
        // rows still need the Align below: without it their bubble starts at
        // the left instead of occupying the right side of the chat.
        padding: EdgeInsets.only(top: topGap),
        child: Stack(
          children: [
            Positioned.fill(
              bottom: reactions.isNotEmpty ? 19 : 0,
              child: IgnorePointer(
                child: AnimatedContainer(
                  key: ValueKey('reply-jump-highlight-${message.id}'),
                  duration:
                      highlighted || MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 350),
                  color: highlighted
                      ? const Color(0xFFE9E1D7)
                      : const Color(0x00E9E1D7),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
                child: bubble,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
