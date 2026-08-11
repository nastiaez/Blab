import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/chat.dart';
import '../../shared/models/message.dart';
import '../../shared/models/message_reaction.dart';
import '../../shared/services/chat_service.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/state/connectivity_state.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/skeletons.dart';
import '../../shared/data/translation_support.dart';
import '../../shared/services/message_translator.dart';
import '../../shared/state/interface_language.dart';
import '../../shared/state/known_languages_state.dart';
import '../../shared/state/push_notifications_state.dart';
import 'state/chat_state.dart';
import 'state/message_reads_state.dart';
import 'state/message_reactions_state.dart';
import 'state/message_translations_state.dart';
import 'state/pending_sends_state.dart';
import 'state/typing_state.dart';
import 'message_actions.dart';
import 'reaction_row_positioning.dart';
import 'services/chat_image_picker.dart';
import 'widgets/chat_composer_input.dart';
import 'widgets/failed_message_sheet.dart';
import 'widgets/first_message_empty_state.dart';
import 'widgets/floating_reaction_row.dart';
import 'widgets/full_emoji_picker_sheet.dart';
import 'widgets/learning_language_sheet.dart';
import 'widgets/message_action_row.dart';
import 'widgets/message_interaction_target.dart';
import 'widgets/message_learning_content.dart';
import 'widgets/message_reaction_bar.dart';
import 'widgets/mode_toggle.dart';
import 'widgets/partner_profile_sheet.dart';
import 'widgets/photo_preview_sheet.dart';
import 'widgets/report_sheet.dart';

// kSupportedLearningLanguages now lives in
// lib/shared/data/translation_support.dart so the chat list tile can
// share the same gate when rendering preview translations.

/// PRD US-013, US-014, US-015, US-016, US-017, US-023.
///
/// Live chat surface backed by Supabase. Header / messages list / input,
/// word popups, long-press actions, and the change-language sheet.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _stackKey = GlobalKey();
  bool _menuOpen = false;
  bool _hasText = false;
  int _textLength = 0;
  double _lastBottomInset = 0;
  int _lastMessageCount = 0;
  Message? _selectedMessage;
  Rect? _selectedBubbleRect;
  Offset? _selectedPressPosition;

  /// Hard cap from PRD US-036.
  static const int _maxMessageLength = kMaxMessageCharacters;

  /// Show the live character counter once we cross this threshold.
  static const int _counterShowAt = 1800;

  /// Cold-open skeleton gate. PRD US-032.
  late final Future<void> _ready;

  /// Tracks the id of the message currently being edited, so we can react to
  /// edit-mode being entered/exited and pre-fill / clear the text field
  /// accordingly. PRD US-019.
  String? _editingMessageId;

  /// Last learning-language code we kicked a DB-cache prefetch for, so a
  /// rebuild doesn't fire the page query again. Cleared by closing the chat
  /// screen (the field is part of the State).
  String? _prefetchedLocaleKey;
  final Set<String> _prefetchedMessageIds = <String>{};
  bool _notificationPermissionTriggered = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final text = _input.text;
      final has = text.trim().isNotEmpty;
      final len = text.characters.length;
      ref.read(typingComposerProvider(widget.chatId)).textChanged(has);
      if (has != _hasText || len != _textLength) {
        setState(() {
          _hasText = has;
          _textLength = len;
        });
      }
    });
    _scroll.addListener(_loadOlderNearTop);
    _ready = Future<void>.delayed(const Duration(milliseconds: 400));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_loadOlderNearTop);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    // Reverse: true list — position 0 is the visual bottom.
    _scroll.jumpTo(0);
  }

  void _loadOlderNearTop() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.maxScrollExtent - _scroll.position.pixels > 240) {
      return;
    }
    ref.read(chatMessagesProvider(widget.chatId).notifier).loadOlder();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    // Defensive — TextField.maxLength enforces this, but guard anyway.
    // PRD US-036.
    if (text.characters.length > _maxMessageLength) return;

    final editing = ref.read(editingProvider(widget.chatId));
    if (editing != null) {
      try {
        await ref
            .read(chatMessagesProvider(widget.chatId).notifier)
            .editMessage(editing.id, text);
        ref.read(editingProvider(widget.chatId).notifier).clear();
        _input.clear();
      } catch (_) {
        if (!mounted) return;
        showAppSnack(context.l10n.couldNotEditMessage);
      }
      return;
    }

    final replyingTo = ref.read(replyingToProvider(widget.chatId));
    ref
        .read(chatMessagesProvider(widget.chatId).notifier)
        .addOutgoing(text, replyTo: replyingTo);
    if (replyingTo != null) {
      ref.read(replyingToProvider(widget.chatId).notifier).clear();
    }
    _input.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _attachImage({required String recipientName}) async {
    FocusScope.of(context).unfocus();
    PickedChatImage? image;
    try {
      image = await ref.read(chatImagePickerProvider).pick(context);
    } catch (_) {
      if (!mounted) return;
      showAppSnack('Could not open photos. Try again.');
      return;
    }
    if (image == null || !mounted) return;
    final caption = await showPhotoPreviewSheet(context, image, recipientName);
    if (caption == null || !mounted) return;
    final replyingTo = ref.read(replyingToProvider(widget.chatId));
    await ref
        .read(chatMessagesProvider(widget.chatId).notifier)
        .addOutgoingPhoto(image, caption: caption, replyTo: replyingTo);
    if (replyingTo != null) {
      ref.read(replyingToProvider(widget.chatId).notifier).clear();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _reportMessage(Message message, Chat chat) async {
    final successMessage = context.l10n.thanksReport;
    final errorMessage = context.l10n.couldNotReport;
    final reason = await showReportReasonSheet(
      context,
      title: context.l10n.reportMessage,
    );
    if (reason == null) return;
    try {
      await ref
          .read(chatServiceProvider)
          .reportContent(
            reason: reason.wire,
            messageId: message.id,
            chatId: chat.id,
            reportedUserId: chat.partnerId,
          );
      showAppSnack(successMessage);
    } catch (_) {
      showAppSnack(errorMessage);
    }
  }

  void _handleAction(Message message, MessageAction action, Chat chat) {
    switch (action) {
      case MessageAction.report:
        _reportMessage(message, chat);
        break;
      case MessageAction.reply:
        ref.read(replyingToProvider(widget.chatId).notifier).set(message);
        break;
      case MessageAction.edit:
        ref.read(editingProvider(widget.chatId).notifier).set(message);
        break;
      case MessageAction.copy:
        Clipboard.setData(ClipboardData(text: message.originalText));
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.copied),
            duration: const Duration(milliseconds: 1500),
          ),
        );
        break;
      case MessageAction.delete:
        final notifier = ref.read(chatMessagesProvider(widget.chatId).notifier);
        final removedId = message.id;
        notifier.removeMessage(removedId);
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.messageDeleted),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: context.l10n.undo,
              textColor: BlabColors.brand,
              onPressed: () {
                notifier.restoreMessage(removedId);
              },
            ),
          ),
        );
        break;
    }
  }

  void _toggleMenu() => setState(() => _menuOpen = !_menuOpen);

  void _closeMenu() {
    if (_menuOpen) setState(() => _menuOpen = false);
  }

  void _selectMessage(Message message, Rect bubbleRect, Offset pressPosition) {
    // Selecting swaps the composer for the action row, so any open keyboard
    // is about to go away. The message list is bottom-anchored, so losing the
    // keyboard inset slides every bubble down by exactly that inset. Bake the
    // shift into the geometry we freeze here, otherwise the floating row
    // lands where the bubble *was* rather than where it ends up.
    final keyboardShift = Offset(0, MediaQuery.viewInsetsOf(context).bottom);
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedMessage = message;
      _selectedBubbleRect = bubbleRect.shift(keyboardShift);
      _selectedPressPosition = pressPosition + keyboardShift;
    });
  }

  void _closeSelection() {
    if (_selectedMessage == null) return;
    setState(() {
      _selectedMessage = null;
      _selectedBubbleRect = null;
      _selectedPressPosition = null;
    });
  }

  String? _viewerReactionEmoji(String messageId) {
    final reactions = ref
        .read(messageReactionsProvider(widget.chatId))
        .value?[messageId];
    if (reactions == null) return null;
    for (final reaction in reactions) {
      if (reaction.reactedByMe) return reaction.emoji;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Resolve the chat via the last-known chat list. Using `.value` instead
    // of `maybeWhen(data: …, orElse: null)` keeps the chat resolved even
    // while the chat-list provider is briefly in AsyncLoading or AsyncError
    // (e.g. during airplane mode, while a refresh is in flight). Otherwise
    // a transient stream error blanks the whole screen to a skeleton.
    final chats = ref.watch(chatListProvider).value;
    Chat? resolved;
    if (chats != null) {
      for (final c in chats) {
        if (c.id == widget.chatId) {
          resolved = c;
          break;
        }
      }
    }

    if (resolved == null) {
      return const Scaffold(
        backgroundColor: BlabColors.appBackground,
        body: SafeArea(child: ChatViewSkeleton()),
      );
    }
    final chat = resolved;
    if (!_notificationPermissionTriggered) {
      _notificationPermissionTriggered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref.read(pushNotificationsProvider.notifier).onFirstChatOpened(),
        );
      });
    }

    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final pagination = ref.watch(chatPaginationProvider(widget.chatId));
    // Keep the read batcher reactive while this screen is open. Its privacy
    // gate starts fail-closed; watching it here lets queued visibility events
    // resume as soon as the saved read-receipt preference finishes loading.
    ref.watch(messageReadsProvider(widget.chatId));
    final replyingTo = ref.watch(replyingToProvider(widget.chatId));
    final editing = ref.watch(editingProvider(widget.chatId));
    final learningLang = ref.watch(learningLanguageProvider(widget.chatId));
    final interfaceLang = ref.watch(interfaceLanguageProvider);
    final online = ref.watch(isOnlineProvider);
    final pushNotifications = ref.watch(pushNotificationsProvider);
    final translationCutoffAt = chat.translationCutoffAt;
    // FR-23: practice mode always targets the chat's learning language;
    // normal mode targets the reader's primary known language. Falls back
    // to the learning language until known languages finish loading.
    final chatMode = ref.watch(chatModeProvider(widget.chatId));
    final knownLanguages = ref.watch(knownLanguagesProvider).value;
    final targetLang = knownLanguages == null
        ? learningLang.code
        : resolveTranslationTarget(
            mode: chatMode,
            learningLanguageCode: learningLang.code,
            primaryKnownLanguageCode: knownLanguages.primary,
          );
    // Keep the auto-disposed composer alive for this chat while its input is
    // mounted. The controller listener reads the same instance on each edit.
    ref.watch(typingComposerProvider(widget.chatId));

    // Hydrate translations one loaded page at a time. History before a
    // language change stays as authored and never enters the AI path.
    final localeKey = '$targetLang|${interfaceLang.code}';
    if (_prefetchedLocaleKey != localeKey) {
      _prefetchedLocaleKey = localeKey;
      _prefetchedMessageIds.clear();
    }
    final loadedMessages = messagesAsync.value ?? const <Message>[];
    final translationCandidates = <String, Message>{};
    for (final message in loadedMessages) {
      void addIfEligible(Message candidate) {
        if (!shouldRequestBubbleTranslation(
          targetLanguageCode: targetLang,
          text: candidate.originalText,
          sentAt: candidate.sentAt,
          translationCutoffAt: translationCutoffAt,
        )) {
          return;
        }
        translationCandidates[candidate.id] = candidate;
      }

      addIfEligible(message);
      final replyTo = message.replyTo;
      if (replyTo != null) addIfEligible(replyTo);
    }
    final allEligibleMessageIds = translationCandidates.keys.toSet();
    final eligibleMessages = translationCandidates.values
        .where((message) => !_prefetchedMessageIds.contains(message.id))
        .toList();
    if (kSupportedLearningLanguages.contains(targetLang) &&
        allEligibleMessageIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(messageTranslationsProvider(widget.chatId).notifier)
            .watchDbRows(allEligibleMessageIds, targetLang, interfaceLang.code);
      });
    }
    if (online && kSupportedLearningLanguages.contains(targetLang)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          ref
              .read(messageTranslationsProvider(widget.chatId).notifier)
              .retryTransientFailures(
                targetLang: targetLang,
                interfaceLang: interfaceLang.code,
              ),
        );
      });
    }
    if (kSupportedLearningLanguages.contains(targetLang) &&
        eligibleMessages.isNotEmpty) {
      _prefetchedMessageIds.addAll(eligibleMessages.map((m) => m.id));
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final notifier = ref.read(
          messageTranslationsProvider(widget.chatId).notifier,
        );
        await notifier.prefetchFromDb(
          eligibleMessages.map((m) => m.id).toList(),
          targetLang,
          interfaceLang.code,
        );
      });
    }

    // Sync the text field with the editing target. Entering edit mode
    // pre-fills with the original text; exiting clears.
    if (editing?.id != _editingMessageId) {
      _editingMessageId = editing?.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (editing != null) {
          _input.text = editing.originalText;
          _input.selection = TextSelection.fromPosition(
            TextPosition(offset: _input.text.length),
          );
        } else {
          _input.clear();
        }
      });
    }

    // With a reverse:true ListView the visual bottom is scroll position 0,
    // which is the natural starting state — no initial-scroll work needed.
    // On message append, the list extends upward (index 0 = newest), so as
    // long as the user is near position 0 we keep them pinned to the
    // bottom; if they've scrolled up to read history, we leave them alone.
    final currentCount = messagesAsync.value?.length ?? 0;
    final chatIsEmpty = messagesAsync.value?.isEmpty == true;
    if (currentCount != _lastMessageCount) {
      _lastMessageCount = currentCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        if (_scroll.position.pixels > 200) return;
        _scrollToBottom();
      });
    }

    // Snap back to the bottom when the keyboard opens, so the input field
    // and the most-recent bubble stay co-visible — but only if the user was
    // already near the bottom. Otherwise this fires on any keyboard-inset
    // change (e.g. the action sheet briefly shifting focus) and yanks the
    // view away from wherever the user actually was, such as a message they
    // just reacted to further up the history.
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    if ((bottomInset - _lastBottomInset).abs() > 1) {
      // A keyboard that *appears* under a live selection shifts the message
      // list up by an amount we can't compensate for after the fact — the
      // bubble geometry behind the floating row was frozen at long-press
      // time. Drop the selection rather than leave a row stranded away from
      // its bubble. A shrinking inset is the keyboard we ourselves dismissed
      // in _selectMessage, which is already accounted for there.
      final keyboardAppeared = bottomInset > _lastBottomInset;
      _lastBottomInset = bottomInset;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (keyboardAppeared) _closeSelection();
        if (!_scroll.hasClients) return;
        if (_scroll.position.pixels > 200) return;
        _scrollToBottom();
      });
    }

    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          key: _stackKey,
          children: [
            Column(
              children: [
                _ChatHeader(
                  chat: chat,
                  onBack: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/chats');
                    }
                  },
                  onMenu: _toggleMenu,
                  onTapPartner: () async {
                    final result = await showPartnerProfileSheet(
                      context,
                      chat: chat,
                    );
                    // Blocking the partner hides this chat — leave the view.
                    if (result == PartnerProfileResult.blocked &&
                        context.mounted) {
                      context.go('/chats');
                    }
                  },
                ),
                if (pushNotifications.reminderVisible)
                  _NotificationReminder(
                    onDismiss: () => ref
                        .read(pushNotificationsProvider.notifier)
                        .dismissReminder(),
                  ),
                const OfflineBanner(),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      _closeMenu();
                      _closeSelection();
                    },
                    child: NotificationListener<ScrollStartNotification>(
                      onNotification: (notification) {
                        // Only a real finger drag dismisses the selection.
                        // Programmatic scrolls (the keyboard-inset snap-back
                        // below calls jumpTo) report no drag details and must
                        // not close the row out from under the user.
                        final isUserDrag = notification.dragDetails != null;
                        if (isUserDrag && _selectedMessage != null) {
                          _closeSelection();
                        }
                        return false;
                      },
                      child: FutureBuilder<void>(
                        future: _ready,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState !=
                              ConnectionState.done) {
                            return const ChatViewSkeleton();
                          }
                          // Show the skeleton only while we have NO data at
                          // all. If the stream errored after a successful
                          // initial yield (e.g. user toggled airplane mode),
                          // keep showing the last-known messages rather than
                          // collapsing to the loading shimmer.
                          final knownMessages = messagesAsync.value;
                          if (knownMessages == null) {
                            return const ChatViewSkeleton();
                          }
                          return Builder(
                            builder: (context) {
                              final messages = knownMessages;
                              final pending = ref.watch(
                                pendingSendsProvider(widget.chatId),
                              );
                              // In-place upgrade: after the server confirms
                              // a send, the pending bubble carries the server's
                              // id + timestamp. As soon as the realtime stream
                              // emits the canonical row the merge layer dedupes
                              // by id, dropping the pending without a flicker.
                              final messageIds = messages
                                  .map((m) => m.id)
                                  .toSet();
                              final pendingVisible = pending
                                  .where((p) => !messageIds.contains(p.id))
                                  .toList();
                              // Optimistic delete overlay: hide anything the
                              // user just deleted, instantly, without waiting
                              // for the realtime row update. US-019.
                              final hidden = ref.watch(
                                hiddenMessagesProvider(widget.chatId),
                              );
                              // Auto-flush queued sends once we're back online
                              // (covers reconnect after airplane mode and
                              // sends interrupted by an app kill, re-hydrated
                              // from disk on cold launch). flushPending guards
                              // in-flight ids, so re-running it per rebuild is
                              // safe. PRD US-030, US-031.
                              if (online &&
                                  pendingVisible.any(
                                    (m) => m.status == MessageStatus.pending,
                                  )) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  ref
                                      .read(
                                        chatMessagesProvider(
                                          widget.chatId,
                                        ).notifier,
                                      )
                                      .flushPending();
                                });
                              }
                              final all =
                                  [...messages, ...pendingVisible]
                                      .where((m) => !hidden.contains(m.id))
                                      .toList()
                                    ..sort(
                                      (a, b) => a.sentAt.compareTo(b.sentAt),
                                    );
                              final reactionsByMessage =
                                  ref
                                      .watch(
                                        messageReactionsProvider(widget.chatId),
                                      )
                                      .value ??
                                  const <
                                    String,
                                    List<MessageReactionSummary>
                                  >{};
                              return _MessageList(
                                chatId: widget.chatId,
                                messages: all,
                                reactionsByMessage: reactionsByMessage,
                                scrollController: _scroll,
                                languageCode: learningLang.code,
                                interfaceLanguageCode: interfaceLang.code,
                                translationCutoffAt: translationCutoffAt,
                                hasOlderMessages: pagination.hasMore,
                                isLoadingOlder: pagination.isLoading,
                                // BUG-009: keep the word popup from drawing on
                                // top of the chat header. Account for the
                                // safe-area notch as well.
                                popupTopInset:
                                    MediaQuery.paddingOf(context).top +
                                    kChatHeaderHeight,
                                emptyState: FirstMessageEmptyState(chat: chat),
                                onLongPress: _selectMessage,
                                onReply: (m) {
                                  HapticFeedback.selectionClick();
                                  ref
                                      .read(
                                        replyingToProvider(
                                          widget.chatId,
                                        ).notifier,
                                      )
                                      .set(m);
                                },
                                onFailedTap: (m) {
                                  final notifier = ref.read(
                                    chatMessagesProvider(
                                      widget.chatId,
                                    ).notifier,
                                  );
                                  showFailedMessageSheet(
                                    context,
                                    onAction: (action) {
                                      switch (action) {
                                        case FailedMessageAction.retry:
                                          notifier.retryFailed(m.id);
                                          break;
                                        case FailedMessageAction.delete:
                                          notifier.dropPending(m.id);
                                          break;
                                      }
                                    },
                                  );
                                },
                                onReact: (m) => showFullEmojiPickerSheet(
                                  context,
                                  interfaceLanguageCode: interfaceLang.code,
                                  onPick: (emoji) => ref
                                      .read(
                                        messageReactionsProvider(
                                          widget.chatId,
                                        ).notifier,
                                      )
                                      .react(messageId: m.id, emoji: emoji),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
                if (replyingTo != null)
                  _ReplyBar(
                    message: replyingTo,
                    partnerName: chat.partnerName,
                    onClose: () => ref
                        .read(replyingToProvider(widget.chatId).notifier)
                        .clear(),
                  ),
                if (editing != null)
                  _EditBar(
                    onClose: () => ref
                        .read(editingProvider(widget.chatId).notifier)
                        .clear(),
                  ),
                _selectedMessage != null
                    ? MessageActionRow(
                        message: _selectedMessage!,
                        onAction: (action) {
                          final message = _selectedMessage!;
                          _closeSelection();
                          _handleAction(message, action, chat);
                        },
                      )
                    : _InputBar(
                        controller: _input,
                        hasText: _hasText,
                        hintText: chatIsEmpty
                            ? context.l10n.sayHi
                            : context.l10n.message,
                        textLength: _textLength,
                        maxLength: _maxMessageLength,
                        counterShowAt: _counterShowAt,
                        onAttach: () =>
                            _attachImage(recipientName: chat.partnerName),
                        onSend: _send,
                        autofocus: chatIsEmpty,
                      ),
              ],
            ),
            if (_menuOpen)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: _closeMenu,
                  child: const SizedBox.shrink(),
                ),
              ),
            if (_menuOpen)
              Positioned(
                top: MediaQuery.paddingOf(context).top + kChatHeaderHeight - 4,
                right: 8,
                child: _ChatMenu(
                  chatId: widget.chatId,
                  onLearningLanguageTap: () async {
                    final saveError = context.l10n.couldNotSaveLearningLanguage;
                    _closeMenu();
                    final current = ref.read(
                      learningLanguageProvider(widget.chatId),
                    );
                    final picked = await showLearningLanguageSheet(
                      context,
                      current: current,
                    );
                    if (picked != null) {
                      try {
                        await ref
                            .read(
                              learningLanguageProvider(widget.chatId).notifier,
                            )
                            .set(picked);
                      } catch (_) {
                        if (!mounted) return;
                        showAppSnack(saveError);
                      }
                    }
                  },
                ),
              ),
            if (_selectedMessage != null &&
                _selectedBubbleRect != null &&
                _selectedPressPosition != null &&
                canReplyToMessage(_selectedMessage!))
              Builder(
                builder: (_) {
                  final stackBox =
                      _stackKey.currentContext?.findRenderObject()
                          as RenderBox?;
                  if (stackBox == null) return const SizedBox.shrink();
                  final minTop = MediaQuery.paddingOf(context).top + 4;
                  final globalTop = computeReactionRowTop(
                    bubbleRect: _selectedBubbleRect!,
                    pressPosition: _selectedPressPosition!,
                    rowHeight: kFloatingReactionRowHeight,
                    minTop: minTop,
                  );
                  final localTopLeft = stackBox.globalToLocal(
                    Offset(_selectedBubbleRect!.center.dx, globalTop),
                  );
                  final screenWidth = MediaQuery.sizeOf(context).width;
                  // max() guard: in a narrow window (split-screen, freeform)
                  // the row can be wider than the screen, which would make
                  // the clamp bounds cross and throw.
                  final maxLeft = math.max(
                    8.0,
                    screenWidth - kFloatingReactionRowWidth - 8.0,
                  );
                  final left = (localTopLeft.dx - kFloatingReactionRowWidth / 2)
                      .clamp(8.0, maxLeft)
                      .toDouble();
                  return Positioned(
                    top: localTopLeft.dy,
                    left: left,
                    child: FloatingReactionRow(
                      selectedEmoji: _viewerReactionEmoji(_selectedMessage!.id),
                      onPick: (emoji) {
                        final message = _selectedMessage!;
                        _closeSelection();
                        ref
                            .read(
                              messageReactionsProvider(widget.chatId).notifier,
                            )
                            .react(messageId: message.id, emoji: emoji);
                      },
                      onMore: () {
                        final message = _selectedMessage!;
                        _closeSelection();
                        showFullEmojiPickerSheet(
                          context,
                          interfaceLanguageCode: interfaceLang.code,
                          onPick: (emoji) => ref
                              .read(
                                messageReactionsProvider(
                                  widget.chatId,
                                ).notifier,
                              )
                              .react(messageId: message.id, emoji: emoji),
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── header ──────────────────────────────────────────

/// Height of the header's back/avatar/name/menu row.
const double kChatHeaderTopRowHeight = 60;

/// Height of the mode-toggle row underneath it — the toggle itself (~32,
/// see [ModeToggle]) plus its bottom padding.
const double kChatHeaderToggleRowHeight = 40;

/// Total header height: consumers (word-popup top inset, the ··· menu's
/// dropdown position) key off this so they stay pinned below the whole
/// header, not just its top row.
const double kChatHeaderHeight =
    kChatHeaderTopRowHeight + kChatHeaderToggleRowHeight;

class _NotificationReminder extends StatelessWidget {
  const _NotificationReminder({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: BlabColors.selectedTint,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_off_outlined,
                size: 19,
                color: BlabColors.textPrimary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.enableNotificationsReminder,
                  style: const TextStyle(
                    fontSize: 13,
                    color: BlabColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: context.l10n.dismiss,
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 19),
                color: BlabColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends ConsumerWidget {
  const _ChatHeader({
    required this.chat,
    required this.onBack,
    required this.onMenu,
    required this.onTapPartner,
  });

  final Chat chat;
  final VoidCallback onBack;
  final VoidCallback onMenu;
  final VoidCallback onTapPartner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnerTyping =
        ref.watch(partnerTypingProvider(chat.id)).value ?? false;
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(4, topInset, 4, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: kChatHeaderTopRowHeight,
            child: Row(
              children: [
                IconButton(
                  tooltip: context.l10n.back,
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 20,
                    color: BlabColors.textPrimary,
                  ),
                  onPressed: onBack,
                  splashRadius: 22,
                ),
                Expanded(
                  child: InkWell(
                    onTap: onTapPartner,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          _HeaderAvatar(
                            name: chat.partnerName,
                            initial: chat.partnerInitial,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _capitaliseName(chat.partnerName),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: BlabColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 150),
                                  child: partnerTyping
                                      ? Padding(
                                          padding: const EdgeInsets.only(
                                            top: 1,
                                          ),
                                          child: Text(
                                            context.l10n.typing,
                                            key: const ValueKey(true),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: BlabColors.brand,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(
                                          key: ValueKey(false),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.chatMenu,
                  icon: const Icon(Icons.more_vert, size: 22),
                  color: BlabColors.textMuted,
                  onPressed: onMenu,
                  splashRadius: 22,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ModeToggle(chatId: chat.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({required this.name, required this.initial});
  final String name;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: BlabColors.avatarColorFor(name),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

// ─────────────────────────── menu ────────────────────────────────────────────

class _ChatMenu extends ConsumerWidget {
  const _ChatMenu({required this.chatId, required this.onLearningLanguageTap});

  final String chatId;
  final VoidCallback onLearningLanguageTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learningLang = ref.watch(learningLanguageProvider(chatId));

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.13),
              blurRadius: 24,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onLearningLanguageTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.learningLanguage,
                        style: const TextStyle(
                          fontSize: 15,
                          color: BlabColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        learningLang.name,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(
                          fontSize: 15,
                          color: BlabColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '›',
                        style: TextStyle(
                          fontSize: 15,
                          color: BlabColors.brand,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

// ─────────────────────────── messages list ───────────────────────────────────

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.chatId,
    required this.messages,
    required this.reactionsByMessage,
    required this.scrollController,
    required this.languageCode,
    required this.interfaceLanguageCode,
    required this.translationCutoffAt,
    required this.hasOlderMessages,
    required this.isLoadingOlder,
    required this.popupTopInset,
    required this.onLongPress,
    required this.onReply,
    required this.onFailedTap,
    required this.onReact,
    this.emptyState,
  });

  final String chatId;
  final List<Message> messages;
  final Map<String, List<MessageReactionSummary>> reactionsByMessage;
  final ScrollController scrollController;
  final String languageCode;
  final String interfaceLanguageCode;
  final DateTime? translationCutoffAt;
  final bool hasOlderMessages;
  final bool isLoadingOlder;
  final double popupTopInset;
  final void Function(Message, Rect, Offset) onLongPress;
  final void Function(Message) onReply;
  final void Function(Message) onFailedTap;
  final void Function(Message) onReact;
  final Widget? emptyState;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return emptyState ?? const SizedBox.expand();
    }

    // Pre-compute rendering hints: date dividers + whether each message is
    // the last in its group (for timestamp/tick visibility).
    final items = <_ListItem>[];
    for (int i = 0; i < messages.length; i++) {
      final m = messages[i];
      final prev = i == 0 ? null : messages[i - 1];
      final next = i == messages.length - 1 ? null : messages[i + 1];

      if (prev == null || !_isSameDay(prev.sentAt, m.sentAt)) {
        items.add(_DateDividerItem(m.sentAt));
      }

      final isFirstInGroup =
          prev == null ||
          prev.isOutgoing != m.isOutgoing ||
          !_isSameDay(prev.sentAt, m.sentAt) ||
          m.sentAt.difference(prev.sentAt).inMinutes.abs() > 2;
      final isLastInGroup =
          next == null ||
          next.isOutgoing != m.isOutgoing ||
          !_isSameDay(next.sentAt, m.sentAt) ||
          next.sentAt.difference(m.sentAt).inMinutes.abs() > 2;

      items.add(
        _MessageItem(
          message: m,
          isFirstInGroup: isFirstInGroup,
          isLastInGroup: isLastInGroup,
        ),
      );
    }

    // Reverse the items so the list can use `reverse: true` — the standard
    // Flutter chat pattern. With reverse:true, scroll position 0 = bottom,
    // index 0 of the array = newest = visually at the bottom. This eliminates
    // a race between the message stream's progressive emissions and our
    // jump-to-bottom logic: the bottom never moves regardless of how many
    // items render.
    final reversed = items.reversed.toList();

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: reversed.length + (hasOlderMessages ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == reversed.length) {
          return SizedBox(
            height: 48,
            child: isLoadingOlder
                ? const Center(
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const SizedBox.shrink(),
          );
        }
        final item = reversed[i];
        if (item is _DateDividerItem) {
          return _DateDivider(when: item.when);
        }
        if (item is _MessageItem) {
          return _MessageRow(
            chatId: chatId,
            message: item.message,
            reactions: reactionsByMessage[item.message.id] ?? const [],
            isFirstInGroup: item.isFirstInGroup,
            isLastInGroup: item.isLastInGroup,
            languageCode: languageCode,
            interfaceLanguageCode: interfaceLanguageCode,
            shouldTranslate: shouldTranslateMessage(
              sentAt: item.message.sentAt,
              translationCutoffAt: translationCutoffAt,
            ),
            translationCutoffAt: translationCutoffAt,
            popupTopInset: popupTopInset,
            onLongPress: (rect, position) =>
                onLongPress(item.message, rect, position),
            onReply: () => onReply(item.message),
            onFailedTap: () => onFailedTap(item.message),
            onReact: () => onReact(item.message),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

String _capitaliseName(String name) =>
    name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

sealed class _ListItem {
  const _ListItem();
}

class _DateDividerItem extends _ListItem {
  const _DateDividerItem(this.when);
  final DateTime when;
}

class _MessageItem extends _ListItem {
  const _MessageItem({
    required this.message,
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });
  final Message message;
  final bool isFirstInGroup;
  final bool isLastInGroup;
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.when});
  final DateTime when;

  @override
  Widget build(BuildContext context) {
    final label = _formatDay(context, when);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: BlabColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDay(BuildContext context, DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(when.year, when.month, when.day);
    final diffDays = today.difference(that).inDays;
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (diffDays == 0) return context.l10n.today;
    if (diffDays == 1) {
      return context.l10n.yesterday;
    }
    if (diffDays < 7) {
      return DateFormat.EEEE(locale).format(when);
    }
    return DateFormat.MMMd(locale).format(when);
  }
}

// ─────────────────────────── message row ─────────────────────────────────────

class _MessageRow extends ConsumerWidget {
  const _MessageRow({
    required this.chatId,
    required this.message,
    required this.reactions,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.languageCode,
    required this.interfaceLanguageCode,
    required this.shouldTranslate,
    required this.translationCutoffAt,
    required this.popupTopInset,
    required this.onLongPress,
    required this.onReply,
    required this.onFailedTap,
    required this.onReact,
  });

  final String chatId;
  final Message message;
  final List<MessageReactionSummary> reactions;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final String languageCode;
  final String interfaceLanguageCode;
  final bool shouldTranslate;
  final DateTime? translationCutoffAt;
  final double popupTopInset;
  final void Function(Rect bubbleRect, Offset pressPosition) onLongPress;
  final VoidCallback onReply;
  final VoidCallback onFailedTap;
  final VoidCallback onReact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOut = message.isOutgoing;
    final topGap = isFirstInGroup ? 10.0 : 2.0;
    final width = MediaQuery.sizeOf(context).width;
    final maxBubble = width * (isOut ? 0.78 : 0.72);
    final isFailed = message.status == MessageStatus.failed;
    final replyTo = message.replyTo;

    // FR-23: practice mode always targets the chat's learning language;
    // normal mode targets the reader's primary known language. Falls back
    // to the learning language until known languages finish loading.
    final mode = ref.watch(chatModeProvider(chatId));
    final knownLanguages = ref.watch(knownLanguagesProvider).value;
    final targetLang = knownLanguages == null
        ? languageCode
        : resolveTranslationTarget(
            mode: mode,
            learningLanguageCode: languageCode,
            primaryKnownLanguageCode: knownLanguages.primary,
          );
    final knownLanguageCodes = knownLanguages?.codes ?? [languageCode];

    final canRequestTranslation =
        shouldTranslate &&
        shouldRequestTranslation(
          targetLanguageCode: targetLang,
          text: message.originalText,
          sentAt: message.sentAt,
          translationCutoffAt: translationCutoffAt,
        );
    final canRequestReplyTranslation =
        replyTo != null &&
        shouldRequestBubbleTranslation(
          targetLanguageCode: targetLang,
          text: replyTo.originalText,
          sentAt: replyTo.sentAt,
          translationCutoffAt: translationCutoffAt,
        );
    final translationNotifier =
        canRequestTranslation || canRequestReplyTranslation
        ? ref.read(messageTranslationsProvider(chatId).notifier)
        : null;
    final readsNotifier = !isOut
        ? ref.read(messageReadsProvider(chatId).notifier)
        : null;

    Widget bubble = MessageInteractionTarget(
      isFailed: isFailed,
      onLongPress: onLongPress,
      onFailedTap: onFailedTap,
      onSwipeReply: canReplyToMessage(message) ? onReply : null,
      child: _Bubble(
        chatId: chatId,
        message: message,
        maxWidth: maxBubble,
        isLastInGroup: isLastInGroup,
        languageCode: languageCode,
        targetLanguageCode: targetLang,
        interfaceLanguageCode: interfaceLanguageCode,
        mode: mode,
        knownLanguageCodes: knownLanguageCodes,
        shouldTranslate: canRequestTranslation,
        replyToShouldTranslate: canRequestReplyTranslation,
        popupTopInset: popupTopInset,
        reactions: reactions,
        onReact: onReact,
      ),
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
              interfaceLang: interfaceLanguageCode,
              priority: message.type == MessageType.image,
            );
          }
          if (canRequestReplyTranslation && info.visibleFraction > 0) {
            translationNotifier!.ensureVisible(
              visibleFraction: info.visibleFraction,
              messageId: replyTo.id,
              text: replyTo.originalText,
              targetLang: targetLang,
              interfaceLang: interfaceLanguageCode,
            );
          }
          // Threshold lowered to 0.5 so partially-visible bubbles still
          // register — bottom-of-list messages were sometimes cropped by
          // the input bar and never crossed 0.9.
          if (!isOut && info.visibleFraction > 0.5) {
            readsNotifier!.reportVisible(message.id);
          }
        },
        child: bubble,
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(12, topGap, 12, 0),
      child: Column(
        crossAxisAlignment: isOut
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [bubble],
      ),
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({
    required this.chatId,
    required this.message,
    required this.reactions,
    required this.maxWidth,
    required this.isLastInGroup,
    required this.languageCode,
    required this.targetLanguageCode,
    required this.interfaceLanguageCode,
    required this.mode,
    required this.knownLanguageCodes,
    required this.shouldTranslate,
    required this.replyToShouldTranslate,
    required this.popupTopInset,
    required this.onReact,
  });

  final String chatId;
  final Message message;
  final List<MessageReactionSummary> reactions;
  final double maxWidth;
  final bool isLastInGroup;

  /// The chat's learning language — used for word-popup/TTS lookups.
  final String languageCode;

  /// The mode-resolved translation target (FR-23): the learning language in
  /// practice mode, or the reader's primary known language in normal mode.
  final String targetLanguageCode;
  final String interfaceLanguageCode;

  /// FR-23: drives MessageLearningContent's single-lane-default branching.
  final ChatMode mode;

  /// The reader's known-language codes — normal mode's source-language
  /// bypass check.
  final List<String> knownLanguageCodes;
  final bool shouldTranslate;
  final bool replyToShouldTranslate;
  final double popupTopInset;
  final VoidCallback onReact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOut = message.isOutgoing;

    final liveTranslation =
        shouldTranslate &&
            kSupportedLearningLanguages.contains(targetLanguageCode)
        ? ref.watch(messageTranslationsProvider(chatId))[translationEntryKey(
            message.id,
            targetLanguageCode,
            interfaceLanguageCode,
          )]
        : null;
    final liveTranslationError =
        liveTranslation is AsyncError<MessageTranslation>
        ? liveTranslation.error
        : null;
    final replyTo = message.replyTo;
    final replyTranslation =
        replyTo != null &&
            replyToShouldTranslate &&
            kSupportedLearningLanguages.contains(targetLanguageCode)
        ? ref.watch(messageTranslationsProvider(chatId))[translationEntryKey(
            replyTo.id,
            targetLanguageCode,
            interfaceLanguageCode,
          )]
        : null;

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
    // of pushing content down in normal flow, so the row needs a little
    // reserved space below for the badge to hang into without crowding the
    // next bubble.
    const reactionBadgeHeight = 22.0;
    const reactionBadgeOverlap = 12.0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: reactions.isNotEmpty
            ? reactionBadgeHeight - reactionBadgeOverlap
            : 0,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: isOut ? Alignment.topRight : Alignment.topLeft,
        children: [
          IntrinsicWidth(
            child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              decoration: BoxDecoration(
                color: isOut ? BlabColors.brand : BlabColors.bubbleIncoming,
                borderRadius: radius,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (replyTo != null) ...[
                    _QuotedReply(
                      replyTo: replyTo,
                      parentIsOutgoing: isOut,
                      translation: replyTranslation,
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (message.attachment != null) ...[
                    _PhotoAttachmentView(attachment: message.attachment!),
                    if (message.originalText.trim().isNotEmpty)
                      const SizedBox(height: 8),
                  ],
                  if (message.originalText.trim().isNotEmpty)
                    MessageLearningContent(
                      messageId: message.id,
                      authoredText: message.originalText,
                      translation: liveTranslation,
                      showTranslation:
                          shouldTranslate &&
                          kSupportedLearningLanguages.contains(
                            targetLanguageCode,
                          ),
                      learningLanguageCode: languageCode,
                      interfaceLanguageCode: interfaceLanguageCode,
                      isOutgoing: isOut,
                      popupTopInset: popupTopInset,
                      mode: mode,
                      knownLanguageCodes: knownLanguageCodes,
                      // TODO(Task 10): _Bubble becomes stateful and owns
                      // real expand state reset by
                      // chatModeResetSignalProvider. Until then this is a
                      // fixed stopgap — there is no icon yet to toggle it.
                      expanded: false,
                      onToggleExpanded: () {},
                      unavailableText:
                          liveTranslationError is MessageTranslationFailed &&
                              liveTranslationError.reason ==
                                  'translation_limit_reached'
                          ? context.l10n.translationLimitReached
                          : context.l10n.translationUnavailable,
                      retryText: context.l10n.retry,
                      onRetry:
                          liveTranslationError is MessageTranslationFailed &&
                              liveTranslationError.reason ==
                                  'translation_limit_reached'
                          ? null
                          : liveTranslation is AsyncError<MessageTranslation>
                          ? () {
                              ref
                                  .read(
                                    messageTranslationsProvider(
                                      chatId,
                                    ).notifier,
                                  )
                                  .retry(
                                    messageId: message.id,
                                    text: message.originalText,
                                    targetLang: targetLanguageCode,
                                    interfaceLang: interfaceLanguageCode,
                                  );
                            }
                          : null,
                    ),
                  if (isLastInGroup) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _Meta(
                        chatId: chatId,
                        message: message,
                        isOutgoing: isOut,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
          if (reactions.isNotEmpty)
            Positioned(
              bottom: -reactionBadgeOverlap,
              left: isOut ? null : 4,
              right: isOut ? 4 : null,
              child: MessageReactionBar(
                reactions: reactions,
                isOutgoing: isOut,
                onTap: onReact,
              ),
            ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({
    required this.chatId,
    required this.message,
    required this.isOutgoing,
  });
  final String chatId;
  final Message message;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context) {
    final timeLabel = _formatTime(message.sentAt);
    final textColor = isOutgoing
        ? Colors.white.withValues(alpha: 0.7)
        : BlabColors.textMuted;
    final children = <Widget>[
      Text(timeLabel, style: TextStyle(fontSize: 11, color: textColor)),
    ];
    if (message.isEdited) {
      children.add(const SizedBox(width: 4));
      children.add(
        Text(
          '· ${context.l10n.edited}',
          style: TextStyle(fontSize: 10, color: textColor),
        ),
      );
    }
    if (message.isOutgoing) {
      children.add(const SizedBox(width: 4));
      children.add(
        _StatusIcon(
          chatId: chatId,
          messageId: message.id,
          intrinsicStatus: message.status,
          isOutgoing: isOutgoing,
        ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  static String _formatTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

ImageProvider<Object>? _attachmentImageProvider(MessageAttachment attachment) {
  final bytes = attachment.localBytes;
  if (bytes != null) return MemoryImage(Uint8List.fromList(bytes));
  final url = attachment.url;
  if (url != null && url.isNotEmpty) return NetworkImage(url);
  return null;
}

class _PhotoAttachmentView extends StatelessWidget {
  const _PhotoAttachmentView({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final provider = _attachmentImageProvider(attachment);
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 220,
        height: 220,
        child: provider == null
            ? Container(
                color: Colors.black.withValues(alpha: 0.08),
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  color: BlabColors.textMuted,
                ),
              )
            : Image(image: provider, fit: BoxFit.cover),
      ),
    );
    return GestureDetector(
      onTap: provider == null
          ? null
          : () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _PhotoPreviewScreen(imageProvider: provider),
              ),
            ),
      child: image,
    );
  }
}

class _PhotoPreviewScreen extends StatelessWidget {
  const _PhotoPreviewScreen({required this.imageProvider});

  final ImageProvider<Object> imageProvider;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image(image: imageProvider, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _StatusIcon extends ConsumerWidget {
  const _StatusIcon({
    required this.chatId,
    required this.messageId,
    required this.intrinsicStatus,
    required this.isOutgoing,
  });

  final String chatId;
  final String messageId;
  final MessageStatus intrinsicStatus;
  final bool isOutgoing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Derive the displayed status from a combination of the message's own
    // state (pending / failed take precedence) and whether the partner has
    // read this message yet. Step 2.2 Task 10 / PRD US-016.
    MessageStatus status = intrinsicStatus;
    if (status == MessageStatus.delivered) {
      final readsAsync = ref.watch(readsForChatProvider(chatId));
      final reads = readsAsync.maybeWhen(
        data: (s) => s,
        orElse: () => const <String>{},
      );
      if (reads.contains(messageId)) {
        status = MessageStatus.read;
      }
    }

    // Semantics labels paired with the icon — read receipts and online
    // indicators must not be color-only. PRD US-033.
    final tint = Colors.white.withValues(alpha: 0.5);
    switch (status) {
      case MessageStatus.pending:
        return Semantics(
          label: context.l10n.sending,
          child: Icon(
            Icons.access_time,
            size: 14,
            color: isOutgoing ? tint : BlabColors.textMuted,
          ),
        );
      case MessageStatus.delivered:
        return Semantics(
          label: context.l10n.delivered,
          child: Icon(
            Icons.done_all,
            size: 14,
            color: isOutgoing ? tint : Colors.grey.shade500,
          ),
        );
      case MessageStatus.read:
        return Semantics(
          label: context.l10n.read,
          child: Icon(
            Icons.done_all,
            size: 14,
            color: isOutgoing ? Colors.white : BlabColors.brand,
          ),
        );
      case MessageStatus.failed:
        return Semantics(
          label: context.l10n.failedToSend,
          child: const Icon(
            Icons.error_outline,
            size: 14,
            color: Color(0xFFEF4444),
          ),
        );
    }
  }
}

// ─────────────────────────── input ───────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.hasText,
    required this.hintText,
    required this.textLength,
    required this.maxLength,
    required this.counterShowAt,
    required this.onAttach,
    required this.onSend,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final bool hasText;
  final String hintText;
  final int textLength;
  final int maxLength;
  final int counterShowAt;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final overLimit = textLength > maxLength;
    final canSend = hasText && !overLimit;
    final showCounter = textLength >= counterShowAt;
    final atLimit = textLength >= maxLength;

    return Container(
      color: BlabColors.cream,
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
                        hintText: hintText,
                        maxLength: maxLength,
                        autofocus: autofocus,
                        attachTooltip: context.l10n.attach,
                        onAttach: onAttach,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: canSend ? 1.0 : 0.4,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Material(
                        color: BlabColors.brand,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: canSend ? onSend : null,
                          child: Tooltip(
                            message: context.l10n.send,
                            child: Icon(
                              Icons.arrow_upward,
                              color: Colors.white,
                              size: 22,
                              semanticLabel: context.l10n.send,
                            ),
                          ),
                        ),
                      ),
                    ),
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
                            ? const Color(0xFFEF4444)
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

class _QuotedReply extends StatelessWidget {
  const _QuotedReply({
    required this.replyTo,
    required this.parentIsOutgoing,
    required this.translation,
  });

  final Message replyTo;
  final bool parentIsOutgoing;
  final AsyncValue<MessageTranslation>? translation;

  @override
  Widget build(BuildContext context) {
    final tintBg = parentIsOutgoing
        ? Colors.white.withValues(alpha: 0.20)
        : BlabColors.brand.withValues(alpha: 0.08);
    final barColor = parentIsOutgoing ? Colors.white : BlabColors.brand;
    final labelColor = parentIsOutgoing ? Colors.white : BlabColors.brand;
    final previewColor = parentIsOutgoing
        ? Colors.white.withValues(alpha: 0.85)
        : BlabColors.textMuted;

    final author = replyTo.isOutgoing ? context.l10n.you : context.l10n.partner;
    final rawPreviewText = switch (translation) {
      AsyncData<MessageTranslation>(value: final value)
          when value.mode != LearningAidMode.none =>
        value.translation,
      _ => replyTo.originalText,
    };
    final previewText = rawPreviewText.trim().isEmpty && replyTo.attachment != null
        ? context.l10n.photoMessagePreview
        : rawPreviewText;
    final attachment = replyTo.attachment;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(color: tintBg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 4, height: 44, color: barColor),
            const SizedBox(width: 8),
            if (attachment != null) ...[
              _ReplyThumbnail(attachment: attachment),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 5, 8, 5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      previewText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: previewColor),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyThumbnail extends StatelessWidget {
  const _ReplyThumbnail({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final provider = _attachmentImageProvider(attachment);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 36,
        height: 36,
        child: provider == null
            ? Container(color: Colors.black.withValues(alpha: 0.08))
            : Image(image: provider, fit: BoxFit.cover),
      ),
    );
  }
}

// ─────────────────────────── reply bar ───────────────────────────────────────

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.message,
    required this.partnerName,
    required this.onClose,
  });

  final Message message;
  final String partnerName;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final whose = message.isOutgoing ? context.l10n.yourself : partnerName;
    final attachment = message.attachment;
    final previewText = message.originalText.trim().isEmpty && attachment != null
        ? context.l10n.photoMessagePreview
        : message.originalText;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.all(12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: BlabColors.brand),
            const SizedBox(width: 10),
            if (attachment != null) ...[
              _ReplyThumbnail(attachment: attachment),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.replyingTo(whose),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BlabColors.brand,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    previewText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: BlabColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onClose,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 20, color: BlabColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── edit bar ────────────────────────────────────────

/// Centered exchange card shown in any chat with no messages yet.
/// PRD US-027.
class _EditBar extends StatelessWidget {
  const _EditBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final accent = Colors.orange.shade600;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.all(12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.editingMessage,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onClose,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 20, color: BlabColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
