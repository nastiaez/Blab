part of '../chat_screen.dart';

class MessageBubble extends ConsumerStatefulWidget {
  const MessageBubble({
    super.key,
    required this.chatId,
    required this.partnerName,
    required this.message,
    required this.reactions,
    required this.maxWidth,
    required this.isLastInGroup,
    required this.languageCode,
    required this.targetLanguageCode,
    required this.replyTargetLanguageCode,
    required this.translationInterfaceLanguageCode,
    required this.mode,
    required this.knownLanguageCodes,
    required this.shouldTranslate,
    required this.replyToShouldTranslate,
    required this.popupTopInset,
    required this.deferTranslationResolve,
    required this.onReact,
    this.onDoubleTapHeart,
    required this.isFailed,
    required this.onLongPress,
    required this.onFailedTap,
    required this.onFailedRetry,
    required this.isSelected,
    required this.showOriginal,
    required this.onJumpToMessage,
    this.onSwipeReply,
    this.selectedBubbleKey,
    this.groupConversation = false,
    this.isFirstInGroup = true,
  });

  final bool groupConversation, isFirstInGroup;
  final String chatId;
  final String partnerName;
  final Message message;
  final List<MessageReactionSummary> reactions;
  final double maxWidth;
  final bool isLastInGroup;

  /// The chat's learning language — used for word-popup/TTS lookups.
  final String languageCode;

  /// The mode-resolved translation target (FR-23): the learning language in
  /// practice mode, or the reader's primary known language in normal mode.
  final String targetLanguageCode;
  final String replyTargetLanguageCode;

  /// The reader's primary known language (modes-known-languages spec): the
  /// translation pipeline's "interface" slot — cache-row key and second-lane
  /// target. Never `profiles.interface_language`.
  final String translationInterfaceLanguageCode;

  /// FR-23: drives MessageLearningContent's single-lane-default branching.
  final ChatMode mode;

  /// The reader's known-language codes — normal mode's source-language
  /// bypass check.
  final List<String> knownLanguageCodes;
  final bool shouldTranslate;
  final bool replyToShouldTranslate;
  final double popupTopInset;
  final bool deferTranslationResolve;

  /// [MessageInteractionTarget]'s gesture-surface inputs — applied inside
  /// this widget's build around the bubble content only (never around the
  /// practice-mode translate icon beside it), so the long-press rect it
  /// measures for the floating reaction row stays the bubble's true bounds.
  final bool isFailed;
  final void Function(Rect bubbleRect, Offset pressPosition) onLongPress;
  final VoidCallback onFailedTap;
  final VoidCallback onFailedRetry;
  final VoidCallback? onSwipeReply;
  final void Function(Message) onJumpToMessage;
  final VoidCallback onReact;
  final VoidCallback? onDoubleTapHeart;
  final bool isSelected;
  final bool showOriginal;
  final GlobalKey? selectedBubbleKey;

  @override
  ConsumerState<MessageBubble> createState() => _BubbleState();
}

class _BubbleState extends ConsumerState<MessageBubble> {
  int _openFormChoiceIndex = 0;

  @override
  void didUpdateWidget(covariant MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id ||
        oldWidget.message.originalText != widget.message.originalText ||
        oldWidget.mode != widget.mode ||
        oldWidget.targetLanguageCode != widget.targetLanguageCode) {
      _openFormChoiceIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formPreferences = ref.watch(
      grammaticalFormPreferencesProvider(widget.chatId),
    );
    final readingScript = ref.watch(readingScriptProvider);

    final message = widget.message;
    final chatId = widget.chatId;
    final reactions = widget.reactions;
    final maxWidth = widget.maxWidth;
    final isLastInGroup = widget.isLastInGroup;
    final languageCode = widget.languageCode;
    final targetLanguageCode = widget.targetLanguageCode;
    final replyTargetLanguageCode = widget.replyTargetLanguageCode;
    final translationInterfaceLanguageCode =
        widget.translationInterfaceLanguageCode;
    final mode = widget.mode;
    final knownLanguageCodes = widget.knownLanguageCodes;
    final shouldTranslate = widget.shouldTranslate;
    final replyToShouldTranslate = widget.replyToShouldTranslate;
    final popupTopInset = widget.popupTopInset;
    final onReact = widget.onReact;
    final isFailed = widget.isFailed;
    final onLongPress = widget.onLongPress;
    final onFailedTap = widget.onFailedTap;
    final onFailedRetry = widget.onFailedRetry;
    final onSwipeReply = widget.onSwipeReply;

    final isOut = message.isOutgoing;
    final isPractice = mode == ChatMode.practice;
    final bubbleColor = isOut
        ? (isPractice
              ? BlabColors.bubbleOutgoingPractice
              : BlabColors.bubbleOutgoingNormal)
        : BlabColors.bubbleIncomingSurface;
    final bubbleOutline = isOut
        ? (isPractice
              ? BlabColors.bubbleOutgoingPracticeOutline
              : BlabColors.bubbleOutgoingNormalOutline)
        : BlabColors.bubbleIncomingOutline;

    final liveTranslation =
        shouldTranslate &&
            kSupportedLearningLanguages.contains(targetLanguageCode)
        ? ref.watch(messageTranslationsProvider(chatId))[translationEntryKey(
            message.id,
            targetLanguageCode,
            translationInterfaceLanguageCode,
          )]
        : null;
    final replyTo = message.replyTo;
    final replyTranslation =
        replyTo != null &&
            replyToShouldTranslate &&
            kSupportedLearningLanguages.contains(replyTargetLanguageCode)
        ? ref.watch(messageTranslationsProvider(chatId))[translationEntryKey(
            replyTo.id,
            replyTargetLanguageCode,
            translationInterfaceLanguageCode,
          )]
        : null;
    final resolvedTranslation = liveTranslation is AsyncData<MessageTranslation>
        ? liveTranslation.value
        : null;
    // Survives the entry falling back to loading/error, so normal mode can
    // tell "the reader can't read this" from "we never found out".
    final resolvedSourceLang =
        resolvedTranslation?.sourceLang ??
        ref
            .read(messageTranslationsProvider(chatId).notifier)
            .resolvedSourceLangFor(message.id);
    final presentation = resolveMessagePresentation(
      authoredText: message.originalText,
      translation: liveTranslation,
      mode: mode,
      knownLanguageCodes: knownLanguageCodes,
      resolvedSourceLang: resolvedSourceLang,
      targetLanguageCode: targetLanguageCode,
      readingScript: readingScript,
    );
    var groupMinWidth = 0.0;
    if (widget.groupConversation && !isOut) {
      final measure = TextPainter(
        text: TextSpan(
          text: presentation.primaryText,
          style: DefaultTextStyle.of(context).style.merge(
            const TextStyle(fontSize: 16, height: 23 / 16, letterSpacing: 0),
          ),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      if (measure.width > (maxWidth - 26) * .9) groupMinWidth = maxWidth;
      measure.dispose();
    }
    final canRetryTranslation =
        liveTranslation is AsyncError<MessageTranslation>;
    void retryTranslation() {
      ref
          .read(messageTranslationsProvider(chatId).notifier)
          .retry(
            messageId: message.id,
            text: message.originalText,
            targetLang: targetLanguageCode,
            interfaceLang: translationInterfaceLanguageCode,
          );
    }

    final formLedger = ref.watch(formCorrectionProvider).asData?.value;
    final resolutionKey = formResolutionKey(
      chatId,
      message.id,
      targetLanguageCode,
    );
    final stored = formLedger?.resolutions[resolutionKey];
    final formChoices =
        resolvedTranslation?.participantFormsFor(targetLanguageCode) ??
        const [];
    final snapshot =
        stored?.sourceText == message.originalText &&
            stored!.alternatives.isParticipantRelevant(targetLanguageCode) &&
            (resolvedTranslation == null || formChoices.isNotEmpty)
        ? stored
        : null;
    if (stored != null && snapshot == null && resolvedTranslation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref
              .read(formCorrectionProvider.notifier)
              .mutate((ledger) {
                if (!mounted || ledger.resolutions[resolutionKey] != stored) {
                  return ledger;
                }
                final current = ref
                    .read(
                      messageTranslationsProvider(chatId),
                    )[translationEntryKey(
                      message.id,
                      targetLanguageCode,
                      translationInterfaceLanguageCode,
                    )]
                    ?.asData
                    ?.value;
                if (current != resolvedTranslation) return ledger;
                return ledger.removeResolution(resolutionKey);
              })
              .catchError((Object _) {}),
        );
      });
    }
    final formAlternatives =
        (snapshot?.alternatives ??
                (formChoices.isEmpty ? null : formChoices.first))
            ?.forMessage(
              isOutgoing: isOut,
              sourceText: message.originalText,
              viewerName:
                  ref.watch(currentProfileProvider).asData?.value.displayName ??
                  context.l10n.you,
              partnerName: widget.partnerName,
            );
    final persistedForm = formAlternatives == null
        ? null
        : switch (formPreferences) {
            AsyncData(:final value) =>
              formAlternatives.subjectIsViewer
                  ? value.ownForm
                  : value.partnerForm,
            _ => null,
          };
    final fallbackForm = formAlternatives == null
        ? null
        : formLedger?.suggestionFor(chatId, formAlternatives.subjectIsViewer) ??
              formAlternatives.suggestedForm;
    final isCurrentNoteTarget = formLedger?.hasNote(resolutionKey) ?? false;
    final noteNeedsTargetTransfer =
        formAlternatives != null &&
        !isCurrentNoteTarget &&
        (formLedger?.hasPersonNoteOnMessage(
              chatId,
              formAlternatives.subjectIsViewer,
              message.id,
            ) ??
            false);
    final resolvedForm = isCurrentNoteTarget && formPreferences.asData != null
        ? persistedForm ?? fallbackForm
        : snapshot?.form ?? persistedForm ?? fallbackForm;
    List<Message> correctionMessages() => [
      ...?ref.read(chatMessagesProvider(chatId)).asData?.value,
      ...ref.read(pendingSendsProvider(chatId)),
    ];
    final noteNeedsReconciliation =
        isCurrentNoteTarget &&
        snapshot != null &&
        resolvedForm != null &&
        snapshot.form != resolvedForm;
    final showLearningAid =
        shouldTranslate &&
        kSupportedLearningLanguages.contains(targetLanguageCode);
    final showParticipantForm =
        showLearningAid &&
        !presentation.unsupportedSource &&
        (isPractice ||
            !knownLanguageCodes.contains(resolvedTranslation?.sourceLang));
    if (showParticipantForm &&
        formLedger != null &&
        (snapshot == null ||
            snapshot.form == null ||
            noteNeedsReconciliation ||
            noteNeedsTargetTransfer ||
            (formAlternatives != null &&
                !formLedger.hasPersonNote(
                  chatId,
                  formAlternatives.subjectIsViewer,
                ))) &&
        formPreferences.asData != null &&
        formAlternatives != null &&
        resolvedForm != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref
              .read(formCorrectionProvider.notifier)
              .mutate((ledger) {
                if (!mounted) return ledger;
                final latestMessages = correctionMessages();
                if (!latestMessages.any(
                  (current) =>
                      current.id == message.id &&
                      current.originalText == message.originalText,
                )) {
                  return ledger;
                }
                final latestPreferences = ref
                    .read(grammaticalFormPreferencesProvider(chatId))
                    .asData
                    ?.value;
                if (latestPreferences == null) return ledger;
                final alreadySaved = formAlternatives.subjectIsViewer
                    ? latestPreferences.ownForm
                    : latestPreferences.partnerForm;
                final effectiveForm =
                    alreadySaved ?? formAlternatives.suggestedForm;
                if (ledger.hasNote(resolutionKey)) {
                  return ledger.reconcileNoteForm(resolutionKey, effectiveForm);
                }
                return ledger.record(
                  FormResolution(
                    chatId: chatId,
                    messageId: message.id,
                    targetLang: targetLanguageCode,
                    sourceText: message.originalText,
                    alternatives: formAlternatives,
                    form: effectiveForm,
                  ),
                  explicit: false,
                  note: true,
                  messages: latestMessages,
                );
              })
              .catchError((Object _) {}),
        );
      });
    }
    Widget buildLearningContent({
      required AsyncValue<MessageTranslation>? translation,
      required bool showTranslation,
      bool pending = false,
    }) => MessageLearningContent(
      groupConversation: widget.groupConversation,
      authoredText: message.originalText,
      translation: translation,
      showTranslation: showTranslation,
      learningLanguageCode: languageCode,
      translationLanguageCode: targetLanguageCode,
      readingScript: readingScript,
      isOutgoing: isOut,
      languagesMatchedAtSend: message.languagesMatchedAtSend,
      popupTopInset: popupTopInset,
      mode: mode,
      knownLanguageCodes: knownLanguageCodes,
      resolvedSourceLang: resolvedSourceLang,
      expanded: widget.isSelected && mode == ChatMode.practice,
      showOriginal: widget.isSelected && widget.showOriginal,
      pendingColor: pending && isPractice
          ? (isOut ? BlabColors.bubbleInk : BlabColors.textPrimary).withValues(
              alpha: 0.48,
            )
          : null,
      onToggleExpanded: () {},
      unavailableText: context.l10n.translationUnavailable,
      retryText: context.l10n.retry,
      onRetry: canRetryTranslation ? retryTranslation : null,
      resolvedForm: resolvedForm,
      formAlternativesOverride: formAlternatives,
      onFormMarkerTap: (index) {
        if (!mounted) return;
        setState(() => _openFormChoiceIndex = index);
      },
      activeFormChoiceIndex: _openFormChoiceIndex,
    );

    final authoredContent = buildLearningContent(
      translation: null,
      showTranslation: false,
      pending: true,
    );
    final finalContent = buildLearningContent(
      translation: liveTranslation,
      showTranslation: showLearningAid,
    );
    final resolvedForLifecycle =
        liveTranslation is AsyncData<MessageTranslation>;
    final unchangedForLifecycle =
        resolvedTranslation != null &&
        translationResultIsUnchanged(message.originalText, resolvedTranslation);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final animateTranslationLifecycle =
        isPractice &&
        showLearningAid &&
        (liveTranslation is! AsyncError<MessageTranslation> ||
            liveTranslation.error is MessageTranslationPending);
    final messageLearningContent = animateTranslationLifecycle
        ? TranslatingMessageContent(
            key: ValueKey(
              'translation-lifecycle-$targetLanguageCode-'
              '${message.originalText.hashCode}',
            ),
            authoredContent: authoredContent,
            finalContent: finalContent,
            resolved: resolvedForLifecycle,
            delivered:
                message.status == MessageStatus.delivered ||
                message.status == MessageStatus.read,
            unchanged: unchangedForLifecycle,
            reduceMotion: reducedMotion,
            outgoing: isOut,
            deferResolve: widget.deferTranslationResolve,
            keepAuthoredDuringFastHold: true,
            animateArrival: false,
            waveBaseColor:
                (isOut ? BlabColors.bubbleInk : BlabColors.textPrimary)
                    .withValues(alpha: 0.48),
            waveHighlightColor: Colors.white,
          )
        : finalContent;

    final BorderRadius radius = isOut
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          );

    // Reactions overlap the bubble's bottom corner (WhatsApp-style) instead
    // of pushing content down in normal flow. Only the top third of the
    // badge sits over the bubble — the rest hangs below it — plus extra
    // reserved space so it's unambiguous which bubble a reaction belongs
    // to when the next message follows close behind.
    const reactionBadgeHeight = 32.0;
    const reactionBadgeOverlap = 21.0;
    const reactionRowGap = 8.0;

    Widget bubbleStack = Padding(
      key: ValueKey('bubble-content-${message.id}'),
      padding: EdgeInsets.only(
        bottom: reactions.isNotEmpty
            ? (reactionBadgeHeight - reactionBadgeOverlap) + reactionRowGap
            : 0,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: isOut ? Alignment.topRight : Alignment.topLeft,
        children: [
          IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: groupMinWidth,
                    maxWidth: maxWidth,
                  ),
                  child: MessageBubbleSurface(
                    outgoing: isOut,
                    practice: isPractice,
                    fill: bubbleColor,
                    outline: bubbleOutline,
                    radius: radius,
                    padding: widget.groupConversation
                        ? const EdgeInsets.fromLTRB(12, 10, 12, 8)
                        : const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.groupConversation &&
                            !isOut &&
                            widget.isFirstInGroup &&
                            message.senderName != null) ...[
                          Text(
                            message.senderName!,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 16 / 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0,
                              color: Color(0xFF9B6550),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        if (replyTo != null) ...[
                          ReplyPreview(
                            replyTo: replyTo,
                            onTap: () => widget.onJumpToMessage(replyTo),
                            partnerName: widget.partnerName,
                            parentIsOutgoing: isOut,
                            translation: replyTranslation?.whenData(
                              (value) =>
                                  (formLedger ?? const FormCorrectionLedger())
                                      .resolveTranslation(
                                        value,
                                        chatId: chatId,
                                        messageId: replyTo.id,
                                        targetLang: replyTargetLanguageCode,
                                        sourceText: replyTo.originalText,
                                      ),
                            ),
                            mode: mode,
                            knownLanguageCodes: knownLanguageCodes,
                            targetLanguageCode: replyTargetLanguageCode,
                            readingScript: readingScript,
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (message.attachment != null) ...[
                          PhotoMessageView(attachment: message.attachment!),
                          if (message.originalText.trim().isNotEmpty)
                            const SizedBox(height: 8),
                        ],
                        if (message.originalText.trim().isNotEmpty)
                          messageLearningContent,
                        if (isLastInGroup || message.isEdited) ...[
                          SizedBox(
                            height: widget.groupConversation && isOut ? 6 : 4,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: MessageMeta(
                              chatId: chatId,
                              message: message,
                              isOutgoing: isOut,
                              groupConversation: widget.groupConversation,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (showParticipantForm &&
                    formAlternatives != null &&
                    resolvedForm != null &&
                    (formLedger?.hasNote(resolutionKey) ?? false))
                  GrammaticalFormNote(
                    form: resolvedForm,
                    person: formAlternatives.subjectName,
                    subjectIsViewer: formAlternatives.subjectIsViewer,
                    onChange: () => context.push(
                      '/chat/$chatId/translation-preferences?name=${Uri.encodeComponent(widget.partnerName)}&subject=${formAlternatives.subjectIsViewer ? 'viewer' : 'partner'}',
                    ),
                  ),
              ],
            ),
          ),
          if (reactions.isNotEmpty)
            Positioned(
              bottom: -reactionBadgeOverlap,
              // A shared pill grows inward from the outer bubble edge,
              // keeping mixed reactions visible even on a very short message.
              left: isOut ? null : 0,
              right: isOut ? 0 : null,
              child: MessageReactionBar(
                reactions: reactions,
                isOutgoing: isOut,
                isPractice: isPractice,
                onTap: onReact,
              ),
            ),
        ],
      ),
    );

    bubbleStack = MessageArrival(
      animate:
          DateTime.now().difference(message.sentAt).abs() <
          const Duration(seconds: 2),
      reduceMotion: reducedMotion,
      outgoing: isOut,
      child: bubbleStack,
    );

    final interactiveBubble = MessageInteractionTarget(
      key: widget.selectedBubbleKey,
      isFailed: isFailed,
      onLongPress: onLongPress,
      onFailedTap: onFailedTap,
      onDoubleTap: message.status == MessageStatus.pending
          ? null
          : widget.onDoubleTapHeart,
      onSwipeReply: onSwipeReply,
      child: bubbleStack,
    );
    final hasError = isFailed || presentation.translationFailed;
    final showUnsupportedLanguageHint =
        presentation.unsupportedSource && showLearningAid;
    if (!hasError && !showUnsupportedLanguageHint) {
      return interactiveBubble;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isOut
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        interactiveBubble,
        if (showUnsupportedLanguageHint)
          UnsupportedLanguageNotice(
            key: const ValueKey('unsupported-language-hint'),
            text: context.l10n.unsupportedLanguageHint,
            alignRight: isOut,
          ),
        if (isFailed) ...[
          if (reactions.isEmpty) const SizedBox(height: 6),
          MessageStatusNotice(
            key: const ValueKey('failed-message-retry'),
            text: context.l10n.failedToSend,
            onTap: onFailedRetry,
            alignRight: isOut,
          ),
        ],
        if (presentation.translationFailed) ...[
          if (!isFailed && reactions.isEmpty) const SizedBox(height: 6),
          if (isFailed) const SizedBox(height: 4),
          MessageStatusNotice(
            key: const ValueKey('translation-message-retry'),
            text: isOut && resolvedSourceLang == targetLanguageCode
                ? context.l10n.couldntCheckRetry
                : context.l10n.couldntTranslateRetry,
            onTap: canRetryTranslation ? retryTranslation : null,
            alignRight: isOut,
          ),
        ],
      ],
    );
  }
}
