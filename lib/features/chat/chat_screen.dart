import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/chat.dart';
import '../../shared/models/message.dart';
import '../../shared/models/message_reaction.dart';
import '../../shared/services/chat_service.dart';
import '../../shared/services/local_chat_history_cache.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/state/connectivity_state.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/skeletons.dart';
import '../../shared/data/translation_support.dart';
import '../../shared/data/languages.dart';
import '../../shared/data/local_storage_keys.dart';
import '../../shared/services/message_translator.dart';
import '../../shared/services/tts_service.dart';
import '../../shared/state/interface_language.dart';
import '../../shared/state/known_languages_state.dart';
import '../../shared/state/push_notifications_state.dart';
import '../../shared/widgets/blab_icon.dart';
import 'state/chat_state.dart';
import 'state/message_reads_state.dart';
import 'state/unread_chat_state.dart';
import 'state/message_reactions_state.dart';
import 'state/message_translations_state.dart';
import 'state/grammatical_form_preferences_state.dart';
import 'state/form_correction_state.dart';
import 'state/pending_sends_state.dart';
import 'state/typing_state.dart';
import 'language_timeline.dart';
import 'message_actions.dart';
import 'message_presentation.dart';
import 'message_translation_lifecycle.dart';
import 'reaction_row_positioning.dart';
import 'services/chat_image_picker.dart';
import 'widgets/chat_composer_input.dart';
import 'widgets/delayed_translation_status.dart';
import 'widgets/failed_message_sheet.dart';
import 'widgets/first_message_empty_state.dart';
import 'widgets/floating_reaction_row.dart';
import 'widgets/full_emoji_picker_sheet.dart';
import 'widgets/reaction_details_sheet.dart';
import 'widgets/learning_language_sheet.dart';
import 'widgets/message_action_row.dart';
import 'widgets/message_interaction_target.dart';
import 'widgets/message_learning_content.dart';
import 'widgets/grammatical_form_note.dart';
import '../../shared/state/profile_state.dart';
import 'widgets/message_reaction_bar.dart';
import 'widgets/mode_toggle.dart';
import 'widgets/partner_profile_sheet.dart';
import 'widgets/photo_preview_sheet.dart';
import 'widgets/report_sheet.dart';
import 'widgets/translating_message_content.dart';

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

enum _ModeTip { practice, normal }

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _selectedBubbleKey = GlobalKey();
  final GlobalKey _unreadDividerKey = GlobalKey();
  final Map<String, GlobalKey> _messageAnchorKeys = <String, GlobalKey>{};
  bool _menuOpen = false;
  bool _hasText = false;
  int _textLength = 0;
  double _lastBottomInset = 0;
  bool _translationResolveDeferred = false;
  int _lastMessageCount = 0;
  Message? _selectedMessage;
  Rect? _selectedBubbleRect;
  Offset? _selectedPressPosition;
  bool _showSelectedOriginal = false;

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
  bool _unreadDividerAnchored = false;
  bool _sessionUnreadCaptured = false;
  List<String> _sessionUnreadIds = const <String>[];
  String? _modeAnchorMessageId;
  double? _modeAnchorOffset;
  bool _modeAnchorAtBottom = false;
  bool _requiredLanguageSheetVisible = false;
  _ModeTip? _visibleModeTip;

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
    _inputFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    // Reverse: true list — position 0 is the visual bottom.
    _scroll.jumpTo(0);
  }

  void _showRequiredLanguageSheetIfNeeded(Chat chat) {
    if (!chat.needsPracticeLanguageSelection || _requiredLanguageSheetVisible) {
      return;
    }
    _requiredLanguageSheetVisible = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final picked = await showRequiredPracticeLanguageSheet(
          context,
          onSelected: (language) => ref
              .read(learningLanguageProvider(widget.chatId).notifier)
              .set(language),
        );
        if (!mounted) return;
        if (picked == null) {
          context.go('/chats');
          return;
        }
        await _showModeTipOnce(_ModeTip.practice);
      } finally {
        _requiredLanguageSheetVisible = false;
      }
    });
  }

  Future<void> _showModeTipOnce(_ModeTip tip) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final preferences = await SharedPreferences.getInstance();
    final key = modeTipSeenStorageKey(userId: userId, mode: tip.name);
    if (preferences.getBool(key) == true || !mounted) return;
    await preferences.setBool(key, true);
    if (mounted) setState(() => _visibleModeTip = tip);
  }

  void _loadOlderNearTop() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.maxScrollExtent - _scroll.position.pixels > 240) {
      return;
    }
    ref.read(chatMessagesProvider(widget.chatId).notifier).loadOlder();
  }

  void _markResolvedAtBottom() {
    if (!_scroll.hasClients || _scroll.position.pixels > 1) return;
    if (ref
            .read(chatListProvider)
            .value
            ?.any(
              (chat) =>
                  chat.id == widget.chatId &&
                  chat.needsPracticeLanguageSelection,
            ) ??
        true) {
      return;
    }
    final messages =
        ref.read(chatMessagesProvider(widget.chatId)).value ??
        const <Message>[];
    final known = ref.read(knownLanguagesProvider).value;
    final mode = ref.read(chatModeProvider(widget.chatId));
    final learning = ref.read(learningLanguageProvider(widget.chatId));
    final timelineValue = ref.read(chatLanguageTimelineProvider(widget.chatId));
    if (!timelineValue.hasValue && !timelineValue.hasError) return;
    final timeline = parseChatLanguageTimeline(
      timelineValue.value ?? const <Map<String, dynamic>>[],
    );
    final interfaceLang = known?.primary ?? '';
    final translations = ref.read(messageTranslationsProvider(widget.chatId));
    final reads = ref.read(messageReadsProvider(widget.chatId).notifier);
    for (final message in messages) {
      final era = languageEraForMessage(
        sentAt: message.sentAt,
        timeline: timeline,
        fallbackLanguageCode: learning.code,
      );
      final target = known == null
          ? ''
          : resolveTranslationTarget(
              mode: mode,
              learningLanguageCode: era.languageCode,
              primaryKnownLanguageCode: known.primary,
            );
      if (message.isOutgoing ||
          !shouldRequestBubbleTranslation(
            targetLanguageCode: target,
            text: message.originalText,
            sentAt: message.sentAt,
            translationCutoffAt: null,
          )) {
        continue;
      }
      final entry =
          translations[translationEntryKey(message.id, target, interfaceLang)];
      if (entry is AsyncData<MessageTranslation> ||
          entry is AsyncError<MessageTranslation>) {
        reads.reportVisible(message.id);
      }
    }
  }

  void _captureModeAnchor() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    _modeAnchorAtBottom = position.pixels <= 1;
    _modeAnchorMessageId = null;
    _modeAnchorOffset = null;
    if (!_modeAnchorAtBottom) {
      final viewport = position.context.storageContext.findRenderObject();
      if (viewport is RenderBox) {
        final viewportTop = viewport.localToGlobal(Offset.zero).dy;
        final viewportBottom = viewportTop + viewport.size.height;
        final visible = <({String id, double top})>[];
        for (final entry in _messageAnchorKeys.entries) {
          final render = entry.value.currentContext?.findRenderObject();
          if (render is! RenderBox || !render.hasSize) continue;
          final top = render.localToGlobal(Offset.zero).dy;
          final bottom = top + render.size.height;
          if (bottom > viewportTop && top < viewportBottom) {
            visible.add((id: entry.key, top: top));
          }
        }
        visible.sort((a, b) => a.top.compareTo(b.top));
        if (visible.isNotEmpty) {
          _modeAnchorMessageId = visible.first.id;
          _modeAnchorOffset = visible.first.top - viewportTop;
        }
      }
    }
    final fallbackOffset = position.pixels;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final nextPosition = _scroll.position;
      if (_modeAnchorAtBottom || _modeAnchorMessageId == null) {
        nextPosition.jumpTo(
          fallbackOffset.clamp(0.0, nextPosition.maxScrollExtent),
        );
        return;
      }
      final context = _messageAnchorKeys[_modeAnchorMessageId!]?.currentContext;
      final render = context?.findRenderObject();
      final anchorOffset = _modeAnchorOffset;
      if (render is RenderBox && anchorOffset != null) {
        final viewport = RenderAbstractViewport.of(render);
        final reveal = viewport.getOffsetToReveal(render, 0);
        nextPosition.jumpTo(
          (reveal.offset - anchorOffset).clamp(
            0.0,
            nextPosition.maxScrollExtent,
          ),
        );
        return;
      }
      nextPosition.jumpTo(
        fallbackOffset.clamp(0.0, nextPosition.maxScrollExtent),
      );
    });
  }

  GlobalKey _messageAnchorKey(String messageId) =>
      _messageAnchorKeys.putIfAbsent(messageId, GlobalKey.new);

  void _anchorOldestUnread() {
    if (!mounted || _unreadDividerAnchored) return;
    final context = _unreadDividerKey.currentContext;
    if (context == null) return;
    _unreadDividerAnchored = true;
    unawaited(
      Scrollable.ensureVisible(context, alignment: 0, duration: Duration.zero),
    );
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

  Future<void> _confirmDelete(Message message, Chat chat) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
          side: BorderSide(color: Color(0xFFE7D7D0)),
        ),
        title: Text(context.l10n.deleteMessageQuestion),
        content: Text(context.l10n.deleteMessageBody(chat.partnerName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              context.l10n.cancel,
              style: const TextStyle(color: BlabColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              context.l10n.delete,
              style: const TextStyle(color: BlabColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(chatMessagesProvider(widget.chatId).notifier)
        .removeMessage(message.id);
  }

  void _showCopiedPill() {
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        right: 0,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 72,
        child: IgnorePointer(
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFECE7E1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                child: Text(
                  context.l10n.copied,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: BlabColors.bubbleInk,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Future<void>.delayed(const Duration(milliseconds: 800), entry.remove);
  }

  bool _needsClipboardPill() {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    final match = RegExp(
      r'(?:Version|Android)\s+(\d+)',
    ).firstMatch(Platform.operatingSystemVersion);
    final androidVersion = int.tryParse(match?.group(1) ?? '');
    return androidVersion != null && androidVersion < 13;
  }

  void _handleAction(
    Message message,
    MessageAction action,
    Chat chat,
    MessagePresentation presentation,
    String learningLanguageCode,
  ) {
    switch (action) {
      case MessageAction.report:
        _reportMessage(message, chat);
        break;
      case MessageAction.reply:
        ref
            .read(replyingToProvider(widget.chatId).notifier)
            .set(message.copyWith(originalText: presentation.primaryText));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _inputFocus.requestFocus();
        });
        break;
      case MessageAction.edit:
        ref.read(editingProvider(widget.chatId).notifier).set(message);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _inputFocus.requestFocus();
        });
        break;
      case MessageAction.copy:
        Clipboard.setData(ClipboardData(text: presentation.primaryText));
        if (_needsClipboardPill()) {
          _showCopiedPill();
        }
        break;
      case MessageAction.listen:
        final text = presentation.listenText;
        if (text == null || !hasSpeakableText(text)) return;
        final tts = ref.read(ttsServiceProvider);
        unawaited(tts.speak(text, learningLanguageCode));
        break;
      case MessageAction.original:
        break;
      case MessageAction.delete:
        unawaited(_confirmDelete(message, chat));
        break;
    }
  }

  void _toggleMenu() => setState(() => _menuOpen = !_menuOpen);

  void _closeMenu() {
    if (_menuOpen) setState(() => _menuOpen = false);
  }

  void _selectMessage(Message message, Rect bubbleRect, Offset pressPosition) {
    if (ref.read(editingProvider(widget.chatId)) != null) return;
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
      _showSelectedOriginal = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncSelectedBubbleGeometry(message.id);
    });
  }

  void _syncSelectedBubbleGeometry(String messageId) {
    if (!mounted || _selectedMessage?.id != messageId) return;
    final renderObject = _selectedBubbleKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final rect = topLeft & renderObject.size;
    final previous = _selectedBubbleRect;
    if (previous != null &&
        (previous.top - rect.top).abs() < 0.5 &&
        (previous.left - rect.left).abs() < 0.5 &&
        (previous.width - rect.width).abs() < 0.5 &&
        (previous.height - rect.height).abs() < 0.5) {
      return;
    }
    setState(() => _selectedBubbleRect = rect);
  }

  void _closeSelection() {
    unawaited(ref.read(ttsServiceProvider).stop());
    if (_selectedMessage == null) return;
    setState(() {
      _selectedMessage = null;
      _selectedBubbleRect = null;
      _selectedPressPosition = null;
      _showSelectedOriginal = false;
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
        backgroundColor: BlabColors.chatCanvas,
        body: SafeArea(child: ChatViewSkeleton()),
      );
    }
    final chat = resolved;
    _showRequiredLanguageSheetIfNeeded(chat);
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
    final unreadValue = ref
        .watch(chatUnreadMessageIdsProvider(widget.chatId))
        .value;
    if (unreadValue != null && !_sessionUnreadCaptured) {
      // Capture the entry boundary once. Read events may empty the provider
      // while the user remains in the chat, but the divider is a session
      // landmark and must not disappear row-by-row.
      _sessionUnreadIds = List<String>.from(unreadValue);
      _sessionUnreadCaptured = true;
    }
    final unreadIds = _sessionUnreadCaptured
        ? _sessionUnreadIds
        : const <String>[];
    final replyingTo = ref.watch(replyingToProvider(widget.chatId));
    final editing = ref.watch(editingProvider(widget.chatId));
    final learningLang = ref.watch(learningLanguageProvider(widget.chatId));
    final languageTimelineValue = ref.watch(
      chatLanguageTimelineProvider(widget.chatId),
    );
    // Wait for the first timeline attempt so old bubbles are never briefly
    // resolved against the current language. Pre-migration/offline fallbacks
    // may still return an error; in that case retain the legacy current-
    // language behavior instead of hiding every learning aid indefinitely.
    final languageTimelineReady = languageTimelineValue.hasValue;
    final languageTimelineRows =
        languageTimelineValue.value ?? const <Map<String, dynamic>>[];
    final languageTimeline = parseChatLanguageTimeline(languageTimelineRows);
    // Account interface language — UI copy only (menus, system text, the
    // emoji-picker locale below). Never a translation target; see
    // translationInterfaceLang below for the pipeline's actual "interface"
    // slot.
    final interfaceLang = ref.watch(interfaceLanguageProvider);
    final online = ref.watch(isOnlineProvider);
    final pushNotifications = ref.watch(pushNotificationsProvider);
    // FR-23 / modes-known-languages spec: practice mode always targets the
    // chat's learning language; normal mode targets the reader's primary
    // known language instead. The server's cache "interface" slot (second
    // lane, and the DB cache-row key) is always the primary known language
    // too — never profiles.interface_language. Both stay '' (never a
    // supported-language match below) until knownLanguagesProvider resolves,
    // so nothing gets translated against a guessed target/interface pair in
    // the meantime (a wrong pair either 404s the cache lookup or trips the
    // client's own interface-language-changed staleness check).
    final chatMode = ref.watch(chatModeProvider(widget.chatId));
    final knownLanguages = ref.watch(knownLanguagesProvider).value;
    final targetLang =
        chat.needsPracticeLanguageSelection || knownLanguages == null
        ? ''
        : resolveTranslationTarget(
            mode: chatMode,
            learningLanguageCode: learningLang.code,
            primaryKnownLanguageCode: knownLanguages.primary,
          );
    final translationInterfaceLang = knownLanguages?.primary ?? '';
    ChatLanguageEra eraForMessage(Message message) => languageEraForMessage(
      sentAt: message.sentAt,
      timeline: languageTimeline,
      fallbackLanguageCode: learningLang.code,
    );
    String targetForMessage(Message message) {
      if (chat.needsPracticeLanguageSelection || knownLanguages == null) {
        return '';
      }
      final era = eraForMessage(message);
      return resolveTranslationTarget(
        mode: chatMode,
        learningLanguageCode: era.languageCode,
        primaryKnownLanguageCode: knownLanguages.primary,
      );
    }

    final selectedMessage = _selectedMessage;
    MessagePresentation? selectedPresentation;
    if (selectedMessage != null &&
        languageTimelineReady &&
        selectedMessage.originalText.trim().isNotEmpty) {
      final selectedTargetLang = targetForMessage(selectedMessage);
      final selectedShouldTranslate = shouldRequestTranslation(
        targetLanguageCode: selectedTargetLang,
        text: selectedMessage.originalText,
        sentAt: selectedMessage.sentAt,
        translationCutoffAt: null,
      );
      final selectedTranslation = selectedShouldTranslate
          ? ref.watch(
              messageTranslationsProvider(widget.chatId),
            )[translationEntryKey(
              selectedMessage.id,
              selectedTargetLang,
              translationInterfaceLang,
            )]
          : null;
      final selectedSourceLang =
          selectedTranslation is AsyncData<MessageTranslation>
          ? selectedTranslation.value.sourceLang
          : ref
                .read(messageTranslationsProvider(widget.chatId).notifier)
                .resolvedSourceLangFor(selectedMessage.id);
      selectedPresentation = resolveMessagePresentation(
        authoredText: selectedMessage.originalText,
        translation: selectedTranslation?.whenData(
          (value) =>
              (ref.watch(formCorrectionProvider).asData?.value ??
                      const FormCorrectionLedger())
                  .resolveTranslation(
                    value,
                    chatId: widget.chatId,
                    messageId: selectedMessage.id,
                    targetLang: selectedTargetLang,
                    sourceText: selectedMessage.originalText,
                  ),
        ),
        mode: chatMode,
        knownLanguageCodes: knownLanguages?.codes ?? const <String>[],
        resolvedSourceLang: selectedSourceLang,
      );
    }
    // Keep the auto-disposed composer alive for this chat while its input is
    // mounted. The controller listener reads the same instance on each edit.
    ref.watch(typingComposerProvider(widget.chatId));

    // Hydrate each message against the viewer-private language era that was
    // active when it arrived. A later language switch must not retarget a
    // completed historical result (US-046 / FR-40).
    final timelineKey = languageTimeline
        .map((era) => '${era.revision}:${era.languageCode}')
        .join(',');
    final localeKey =
        '${chatMode.name}|$targetLang|$translationInterfaceLang|$timelineKey';
    if (_prefetchedLocaleKey != localeKey) {
      _prefetchedLocaleKey = localeKey;
      _prefetchedMessageIds.clear();
    }
    final loadedMessages = messagesAsync.value ?? const <Message>[];
    final translationCandidateGroups =
        <String, List<({Message message, ChatLanguageEra era})>>{};
    final variantTargets = <String, String>{};
    for (final message in loadedMessages) {
      void addIfEligible(Message candidate) {
        if (!languageTimelineReady) return;
        // Translation begins after delivery. In particular, photo captions
        // can spend a short time pending while the image uploads; starting
        // the resolver then can finish before delivery and skip the wave.
        if (candidate.isOutgoing &&
            candidate.status != MessageStatus.delivered &&
            candidate.status != MessageStatus.read) {
          return;
        }
        final era = eraForMessage(candidate);
        final candidateTarget = targetForMessage(candidate);
        if (!shouldRequestBubbleTranslation(
          targetLanguageCode: candidateTarget,
          text: candidate.originalText,
          sentAt: candidate.sentAt,
          translationCutoffAt: null,
        )) {
          return;
        }
        final variantKey =
            '$candidateTarget|${era.languageCode}|${era.revision}';
        variantTargets[variantKey] = candidateTarget;
        final group = translationCandidateGroups.putIfAbsent(
          variantKey,
          () => <({Message message, ChatLanguageEra era})>[],
        );
        if (!group.any((entry) => entry.message.id == candidate.id)) {
          group.add((message: candidate, era: era));
        }
      }

      addIfEligible(message);
      final replyTo = message.replyTo;
      if (replyTo != null) addIfEligible(replyTo);
    }
    final liveMessageIds = translationCandidateGroups.entries
        .where((entry) => variantTargets[entry.key] == targetLang)
        .expand((entry) => entry.value)
        .where((entry) => entry.era.languageCode == learningLang.code)
        .map((entry) => entry.message.id)
        .toSet();
    if (kSupportedLearningLanguages.contains(targetLang) &&
        liveMessageIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(messageTranslationsProvider(widget.chatId).notifier)
            .watchDbRows(liveMessageIds, targetLang, translationInterfaceLang);
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
                interfaceLang: translationInterfaceLang,
              ),
        );
      });
    }
    for (final groupEntry in translationCandidateGroups.entries) {
      final target = variantTargets[groupEntry.key]!;
      final eligible = groupEntry.value
          .where(
            (entry) => !_prefetchedMessageIds.contains(
              '${groupEntry.key}|${entry.message.id}',
            ),
          )
          .toList();
      if (!kSupportedLearningLanguages.contains(target) || eligible.isEmpty) {
        continue;
      }
      _prefetchedMessageIds.addAll(
        eligible.map((entry) => '${groupEntry.key}|${entry.message.id}'),
      );
      final era = eligible.first.era;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final notifier = ref.read(
          messageTranslationsProvider(widget.chatId).notifier,
        );
        await notifier.prefetchFromDb(
          eligible.map((entry) => entry.message.id).toList(),
          target,
          translationInterfaceLang,
          packageLearningLanguage: era.languageCode,
          packageLanguageRevision: era.revision,
          sourceTexts: {
            for (final entry in eligible)
              entry.message.id: entry.message.originalText,
          },
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
          _inputFocus.requestFocus();
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

    final practiceHint = chatMode == ChatMode.practice
        ? context.l10n.practiceComposerHint(
            learningLang.name,
            _languageNameForCode(knownLanguages?.primary),
          )
        : null;
    final activePresentation =
        selectedPresentation ??
        MessagePresentation(
          primaryText: selectedMessage?.originalText ?? '',
          originalText: selectedMessage?.originalText ?? '',
          canRevealOriginal: false,
        );

    if (_selectedMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncSelectedBubbleGeometry(_selectedMessage!.id);
      });
    }

    return PopScope(
      canPop: _selectedMessage == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedMessage != null) _closeSelection();
      },
      child: Scaffold(
        backgroundColor: BlabColors.chatCanvas,
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
                    onBeforeModeToggle: _captureModeAnchor,
                    onModeChanged: (mode) {
                      if (mode == ChatMode.normal) {
                        unawaited(_showModeTipOnce(_ModeTip.normal));
                      }
                    },
                    practiceSetupRequired: chat.needsPracticeLanguageSelection,
                    selectionActive: _selectedMessage != null,
                    onDismissSelection: _closeSelection,
                    onBack: () {
                      if (_selectedMessage != null) {
                        _closeSelection();
                        return;
                      }
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/chats');
                      }
                    },
                    onMenu: () {
                      if (_selectedMessage != null) {
                        _closeSelection();
                        return;
                      }
                      _toggleMenu();
                    },
                    onTapPartner: () async {
                      if (_selectedMessage != null) {
                        _closeSelection();
                        return;
                      }
                      final result = await showPartnerProfileSheet(
                        context,
                        chat: chat,
                      );
                      // Blocking the partner hides this chat — leave the view.
                      if (result == PartnerProfileResult.blocked &&
                          context.mounted) {
                        context.go('/chats');
                      } else if (context.mounted && editing != null) {
                        _inputFocus.requestFocus();
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
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          // Only a real finger drag dismisses the selection.
                          // Programmatic scrolls (the keyboard-inset snap-back
                          // below calls jumpTo) report no drag details and must
                          // not close the row out from under the user.
                          final isUserDrag =
                              notification is ScrollStartNotification &&
                              notification.dragDetails != null;
                          if (isUserDrag && _selectedMessage != null) {
                            _closeSelection();
                          }
                          if (isUserDrag && !_translationResolveDeferred) {
                            setState(() => _translationResolveDeferred = true);
                          } else if (notification is ScrollEndNotification &&
                              _translationResolveDeferred) {
                            setState(() => _translationResolveDeferred = false);
                          }
                          if (notification is ScrollEndNotification) {
                            _markResolvedAtBottom();
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
                                if (unreadIds.isNotEmpty &&
                                    !_unreadDividerAnchored) {
                                  WidgetsBinding.instance.addPostFrameCallback(
                                    (_) => _anchorOldestUnread(),
                                  );
                                }
                                final reactionsByMessage =
                                    ref
                                        .watch(
                                          messageReactionsProvider(
                                            widget.chatId,
                                          ),
                                        )
                                        .value ??
                                    const <
                                      String,
                                      List<MessageReactionSummary>
                                    >{};
                                return _MessageList(
                                  chatId: widget.chatId,
                                  partnerName: chat.partnerName,
                                  messages: all,
                                  reactionsByMessage: reactionsByMessage,
                                  scrollController: _scroll,
                                  languageCode: learningLang.code,
                                  languageTimelineRows: languageTimelineRows,
                                  languageTimelineReady: languageTimelineReady,
                                  practiceSetupRequired:
                                      chat.needsPracticeLanguageSelection,
                                  translationInterfaceLanguageCode:
                                      translationInterfaceLang,
                                  unreadMessageIds: unreadIds,
                                  unreadDividerKey: _unreadDividerKey,
                                  messageAnchorKey: _messageAnchorKey,
                                  hasOlderMessages: pagination.hasMore,
                                  isLoadingOlder: pagination.isLoading,
                                  deferTranslationResolve:
                                      _translationResolveDeferred,
                                  // BUG-009: keep the word popup from drawing on
                                  // top of the chat header. Account for the
                                  // safe-area notch as well.
                                  popupTopInset:
                                      MediaQuery.paddingOf(context).top +
                                      kChatHeaderHeight,
                                  selectedMessageId: _selectedMessage?.id,
                                  showSelectedOriginal: _showSelectedOriginal,
                                  selectedBubbleKey: _selectedBubbleKey,
                                  emptyState: FirstMessageEmptyState(
                                    chat: chat,
                                  ),
                                  onLongPress: _selectMessage,
                                  onReply: (m) {
                                    if (editing != null) return;
                                    _closeSelection();
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
                                  onFailedRetry: (m) => ref
                                      .read(
                                        chatMessagesProvider(
                                          widget.chatId,
                                        ).notifier,
                                      )
                                      .retryFailed(m.id),
                                  onReact: (m) => showReactionDetailsSheet(
                                    context,
                                    reactions:
                                        reactionsByMessage[m.id] ?? const [],
                                    partnerName: chat.partnerName,
                                    onChangeReaction: (emoji) => ref
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
                          mode: chatMode,
                          hasOriginal: activePresentation.canRevealOriginal,
                          canListen:
                              activePresentation.listenText != null &&
                              hasSpeakableText(activePresentation.listenText!),
                          isOriginalVisible: _showSelectedOriginal,
                          onAction: (action) {
                            final message = _selectedMessage!;
                            if (action == MessageAction.original) {
                              setState(
                                () => _showSelectedOriginal =
                                    !_showSelectedOriginal,
                              );
                              return;
                            }
                            if (action == MessageAction.listen) {
                              _handleAction(
                                message,
                                action,
                                chat,
                                activePresentation,
                                learningLang.code,
                              );
                              return;
                            }
                            _closeSelection();
                            _handleAction(
                              message,
                              action,
                              chat,
                              activePresentation,
                              learningLang.code,
                            );
                          },
                        )
                      : AbsorbPointer(
                          absorbing: chat.needsPracticeLanguageSelection,
                          child: Opacity(
                            opacity: chat.needsPracticeLanguageSelection
                                ? .45
                                : 1,
                            child: _InputBar(
                              controller: _input,
                              focusNode: _inputFocus,
                              hasText: _hasText,
                              hintText:
                                  practiceHint ??
                                  (chatIsEmpty
                                      ? context.l10n.sayHi
                                      : context.l10n.message),
                              textLength: _textLength,
                              maxLength: _maxMessageLength,
                              counterShowAt: _counterShowAt,
                              isPractice: chatMode == ChatMode.practice,
                              showTopBorder: replyingTo == null,
                              onAttach: () =>
                                  _attachImage(recipientName: chat.partnerName),
                              onSend: _send,
                              autofocus:
                                  chatIsEmpty ||
                                  replyingTo != null ||
                                  editing != null,
                              allowAttachment: editing == null,
                            ),
                          ),
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
                  top:
                      MediaQuery.paddingOf(context).top + kChatHeaderHeight - 4,
                  right: 8,
                  child: _ChatMenu(
                    chatId: widget.chatId,
                    onLearningLanguageTap: () async {
                      final saveError =
                          context.l10n.couldNotSaveLearningLanguage;
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
                                learningLanguageProvider(
                                  widget.chatId,
                                ).notifier,
                              )
                              .set(picked);
                        } catch (_) {
                          if (!mounted) return;
                          showAppSnack(saveError);
                        }
                      }
                      if (mounted && editing != null) {
                        _inputFocus.requestFocus();
                      }
                    },
                    onTranslationPreferencesTap: () async {
                      _closeMenu();
                      await context.push(
                        '/chat/${widget.chatId}/translation-preferences?name=${Uri.encodeComponent(chat.partnerName)}',
                      );
                      if (mounted && editing != null) {
                        _inputFocus.requestFocus();
                      }
                    },
                  ),
                ),
              if (_visibleModeTip != null)
                Positioned(
                  top:
                      MediaQuery.paddingOf(context).top + kChatHeaderHeight + 8,
                  right: 16,
                  child: TapRegion(
                    onTapOutside: (_) => setState(() => _visibleModeTip = null),
                    child: _ModeTipCard(
                      tip: _visibleModeTip!,
                      practiceLanguage: learningLang.name,
                      primaryKnownLanguage: _languageNameForCode(
                        knownLanguages?.primary,
                      ),
                      onDismiss: () => setState(() => _visibleModeTip = null),
                      onEditKnownLanguages: () {
                        setState(() => _visibleModeTip = null);
                        context.push('/profile/known-languages');
                      },
                    ),
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
                    if (stackBox == null || !stackBox.hasSize) {
                      return const SizedBox.shrink();
                    }
                    // Reading live render-tree geometry mid-build can race a
                    // route transition — e.g. tapping a photo right after
                    // picking an emoji, while this frame's tree is still
                    // mid-layout from the selection closing. Fail soft: skip
                    // the row for that one frame instead of crashing; it's
                    // gone by the next frame regardless since the selection
                    // just closed.
                    double localTop;
                    try {
                      final padding = MediaQuery.paddingOf(context);
                      final minTop = padding.top + 4;
                      final stackBottom = stackBox
                          .localToGlobal(Offset(0, stackBox.size.height))
                          .dy;
                      final maxBottom =
                          stackBottom -
                          padding.bottom -
                          kMessageActionRowMinHeight;
                      final globalTop = computeReactionRowTop(
                        bubbleRect: _selectedBubbleRect!,
                        pressPosition: _selectedPressPosition!,
                        rowHeight: kFloatingReactionRowHeight,
                        minTop: minTop,
                        maxBottom: maxBottom,
                      );
                      localTop = stackBox
                          .globalToLocal(Offset(0, globalTop))
                          .dy;
                    } catch (_) {
                      return const SizedBox.shrink();
                    }
                    // Centered on the stack rather than the bubble, so the
                    // row sits the same distance from both edges regardless
                    // of which side the bubble is on. Measured against the
                    // stack's own width (not the full screen) so it lines up
                    // even when SafeArea reserves horizontal space, and kept
                    // clear of the physical edges — curved-edge phones and
                    // Android's edge-swipe-back gesture both eat touches in
                    // the outermost strip, which made the leftmost/rightmost
                    // buttons unreliable to tap.
                    final stackWidth = stackBox.size.width;
                    const edgeMargin = 16.0;
                    final centered =
                        (stackWidth - kFloatingReactionRowWidth) / 2;
                    final maxLeft =
                        stackWidth - kFloatingReactionRowWidth - edgeMargin;
                    final left = maxLeft >= edgeMargin
                        ? centered.clamp(edgeMargin, maxLeft)
                        : centered;
                    return Positioned(
                      top: localTop,
                      left: left,
                      child: FloatingReactionRow(
                        selectedEmoji: _viewerReactionEmoji(
                          _selectedMessage!.id,
                        ),
                        onPick: (emoji) {
                          final message = _selectedMessage!;
                          _closeSelection();
                          ref
                              .read(
                                messageReactionsProvider(
                                  widget.chatId,
                                ).notifier,
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
      ),
    );
  }
}

// ─────────────────────────── header ──────────────────────────────────────────

/// Height of the header's back/avatar/name/menu row.
const double kChatHeaderTopRowHeight = 56;
const double kChatHeaderHeight = 56;

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
    required this.onBeforeModeToggle,
    required this.onModeChanged,
    required this.practiceSetupRequired,
    required this.onBack,
    required this.onMenu,
    required this.onTapPartner,
    required this.selectionActive,
    required this.onDismissSelection,
  });

  final Chat chat;
  final VoidCallback onBeforeModeToggle;
  final ValueChanged<ChatMode> onModeChanged;
  final bool practiceSetupRequired;
  final VoidCallback onBack;
  final VoidCallback onMenu;
  final VoidCallback onTapPartner;
  final bool selectionActive;
  final VoidCallback onDismissSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnerTyping =
        ref.watch(partnerTypingProvider(chat.id)).value ?? false;
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(4, topInset, 4, 0),
      decoration: const BoxDecoration(
        color: BlabColors.chatSurface,
        border: Border(bottom: BorderSide(color: BlabColors.chatDivider)),
      ),
      child: SizedBox(
        height: kChatHeaderTopRowHeight,
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 56,
              child: IconButton(
                tooltip: context.l10n.back,
                padding: const EdgeInsets.only(left: 4),
                icon: const BlabIcon(
                  name: 'nav-arrow-left - 20',
                  color: BlabColors.textPrimary,
                  size: 20,
                ),
                onPressed: onBack,
                splashRadius: 22,
              ),
            ),
            Expanded(
              child: InkWell(
                onTap: onTapPartner,
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: [
                    _HeaderAvatar(name: chat.partnerName),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _capitaliseName(chat.partnerName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: BlabColors.sendButton,
                            ),
                          ),
                          if (partnerTyping)
                            Padding(
                              padding: const EdgeInsets.only(top: 1),
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
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: selectionActive ? onDismissSelection : null,
              child: AbsorbPointer(
                absorbing: selectionActive || practiceSetupRequired,
                child: ModeToggle(
                  chatId: chat.id,
                  onBeforeToggle: onBeforeModeToggle,
                  onModeChanged: onModeChanged,
                ),
              ),
            ),
            SizedBox(
              width: 44,
              height: 56,
              child: IconButton(
                tooltip: context.l10n.chatMenu,
                icon: const BlabIcon(
                  name: 'more-vert - 20',
                  color: BlabColors.textPrimary,
                  size: 20,
                ),
                onPressed: practiceSetupRequired ? null : onMenu,
                splashRadius: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: BlabColors.avatarColorFor(name),
        boxShadow: const [
          BoxShadow(
            color: Color(0x21231208),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        BlabColors.avatarInitialsFor(name),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ModeTipCard extends StatelessWidget {
  const _ModeTipCard({
    required this.tip,
    required this.practiceLanguage,
    required this.primaryKnownLanguage,
    required this.onDismiss,
    required this.onEditKnownLanguages,
  });

  final _ModeTip tip;
  final String practiceLanguage;
  final String primaryKnownLanguage;
  final VoidCallback onDismiss;
  final VoidCallback onEditKnownLanguages;

  @override
  Widget build(BuildContext context) {
    final practice = tip == _ModeTip.practice;
    final title = practice ? 'Practice mode' : 'Normal mode';
    final body = practice
        ? 'Messages appear in $practiceLanguage. Blab helps correct mistakes and translates from $primaryKnownLanguage. Switch to Normal to see the original.'
        : 'Messages in languages you know stay as written. Others are translated for you. Long-press to see the original.';
    return Material(
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 280,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF88C5A),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33231208),
                  offset: Offset(0, 2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF46281C),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkResponse(
                      onTap: onDismiss,
                      radius: 20,
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Color(0xFF46281C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF46281C),
                    fontSize: 12,
                    height: 16 / 12,
                  ),
                ),
                if (!practice) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onEditKnownLanguages,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: const Color(0xFF46281C),
                    ),
                    child: const Text(
                      'Edit known languages',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: -6,
            right: (practice ? 135 : 129) / 2 + 26,
            child: const IgnorePointer(
              child: CustomPaint(
                key: ValueKey('mode-tip-pointer'),
                size: Size(12, 6),
                painter: _ModeTipPointerPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeTipPointerPainter extends CustomPainter {
  const _ModeTipPointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final pointer = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(pointer, Paint()..color = const Color(0xFFF88C5A));
  }

  @override
  bool shouldRepaint(_ModeTipPointerPainter oldDelegate) => false;
}

// ─────────────────────────── menu ────────────────────────────────────────────

class _ChatMenu extends ConsumerWidget {
  const _ChatMenu({
    required this.chatId,
    required this.onLearningLanguageTap,
    required this.onTranslationPreferencesTap,
  });

  final String chatId;
  final VoidCallback onLearningLanguageTap;
  final VoidCallback onTranslationPreferencesTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learningLang = ref.watch(learningLanguageProvider(chatId));

    return Material(
      color: Colors.transparent,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: BlabColors.chatSurface,
          border: Border.all(color: BlabColors.chatDivider),
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A231208),
              blurRadius: 12,
              offset: Offset(0, 2),
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
                child: SizedBox(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.learningLanguage,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: BlabColors.sendButton,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              learningLang.name,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Color(0xFF917869),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const BlabIcon(
                              name: 'nav-arrow-right - 20',
                              color: Color(0xFF917869),
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(
                height: 1,
                thickness: 1,
                color: BlabColors.chatDivider,
              ),
              InkWell(
                onTap: onTranslationPreferencesTap,
                child: SizedBox(
                  height: 52,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'Translation preferences',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: BlabColors.sendButton,
                          ),
                        ),
                        SizedBox(width: 16),
                        BlabIcon(
                          name: 'nav-arrow-right - 20',
                          color: Color(0xFF917869),
                          size: 20,
                        ),
                      ],
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

// ─────────────────────────── messages list ───────────────────────────────────

class _MessageList extends ConsumerWidget {
  const _MessageList({
    required this.chatId,
    required this.partnerName,
    required this.messages,
    required this.reactionsByMessage,
    required this.scrollController,
    required this.languageCode,
    required this.languageTimelineRows,
    required this.languageTimelineReady,
    required this.practiceSetupRequired,
    required this.translationInterfaceLanguageCode,
    required this.unreadMessageIds,
    required this.unreadDividerKey,
    required this.messageAnchorKey,
    required this.hasOlderMessages,
    required this.isLoadingOlder,
    required this.deferTranslationResolve,
    required this.popupTopInset,
    required this.onLongPress,
    required this.onReply,
    required this.onFailedTap,
    required this.onFailedRetry,
    required this.onReact,
    required this.selectedMessageId,
    required this.showSelectedOriginal,
    required this.selectedBubbleKey,
    this.emptyState,
  });

  final String chatId;
  final String partnerName;
  final List<Message> messages;
  final Map<String, List<MessageReactionSummary>> reactionsByMessage;
  final ScrollController scrollController;
  final String languageCode;
  final List<Map<String, dynamic>> languageTimelineRows;
  final bool languageTimelineReady;
  final bool practiceSetupRequired;

  /// The reader's primary known language (modes-known-languages spec): the
  /// translation pipeline's "interface" slot — cache-row key and second-lane
  /// target — never `profiles.interface_language`.
  final String translationInterfaceLanguageCode;
  final List<String> unreadMessageIds;
  final GlobalKey unreadDividerKey;
  final GlobalKey Function(String messageId) messageAnchorKey;
  final bool hasOlderMessages;
  final bool isLoadingOlder;
  final bool deferTranslationResolve;
  final double popupTopInset;
  final void Function(Message, Rect, Offset) onLongPress;
  final void Function(Message) onReply;
  final void Function(Message) onFailedTap;
  final void Function(Message) onFailedRetry;
  final void Function(Message) onReact;
  final String? selectedMessageId;
  final bool showSelectedOriginal;
  final GlobalKey selectedBubbleKey;
  final Widget? emptyState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (messages.isEmpty) {
      return emptyState ?? const SizedBox.expand();
    }

    final mode = ref.watch(chatModeProvider(chatId));
    final knownLanguages = ref.watch(knownLanguagesProvider).value;
    final languageTimeline = parseChatLanguageTimeline(languageTimelineRows);
    ChatLanguageEra eraForMessage(Message message) => languageEraForMessage(
      sentAt: message.sentAt,
      timeline: languageTimeline,
      fallbackLanguageCode: languageCode,
    );
    String targetForMessage(Message message) {
      if (practiceSetupRequired || knownLanguages == null) return '';
      return resolveTranslationTarget(
        mode: mode,
        learningLanguageCode: eraForMessage(message).languageCode,
        primaryKnownLanguageCode: knownLanguages.primary,
      );
    }

    final translationState = ref.watch(messageTranslationsProvider(chatId));
    final languageChanges = languageTimelineRows
        .where((event) => (event['revision'] as num?)?.toInt() != 1)
        .map(
          (event) => (
            when: DateTime.tryParse(event['created_at'] as String? ?? ''),
            language: event['learning_language'] as String?,
          ),
        )
        .where((event) => event.when != null && event.language != null)
        .toList();
    final pendingIncoming = messages.where((message) {
      if (!languageTimelineReady) return false;
      final targetLanguage = targetForMessage(message);
      if (message.isOutgoing ||
          !shouldRequestBubbleTranslation(
            targetLanguageCode: targetLanguage,
            text: message.originalText,
            sentAt: message.sentAt,
            translationCutoffAt: null,
          )) {
        return false;
      }
      final entry =
          translationState[translationEntryKey(
            message.id,
            targetLanguage,
            translationInterfaceLanguageCode,
          )];
      return entry is! AsyncData<MessageTranslation> &&
          entry is! AsyncError<MessageTranslation>;
    }).toList();
    final firstPendingId = pendingIncoming.firstOrNull?.id;
    final pendingIds = pendingIncoming.map((message) => message.id).toSet();
    final hasEarlierPending = <String, bool>{};
    var earlierPending = false;
    for (final message in messages) {
      hasEarlierPending[message.id] = earlierPending;
      if (pendingIds.contains(message.id)) earlierPending = true;
    }

    // Pre-compute rendering hints: date dividers + whether each message is
    // the last in its group (for timestamp/tick visibility).
    final items = <_ListItem>[];
    var languageChangeIndex = 0;
    for (int i = 0; i < messages.length; i++) {
      final m = messages[i];
      final prev = i == 0 ? null : messages[i - 1];
      final next = i == messages.length - 1 ? null : messages[i + 1];
      final startsNewDate = prev == null || !_isSameDay(prev.sentAt, m.sentAt);
      final isFirstInGroup =
          prev == null ||
          prev.isOutgoing != m.isOutgoing ||
          startsNewDate ||
          m.sentAt.difference(prev.sentAt).inMinutes.abs() > 2;
      final messageTopGap = isFirstInGroup ? 10.0 : 2.0;

      if (startsNewDate) {
        items.add(_DateDividerItem(m.sentAt));
      }
      while (languageChangeIndex < languageChanges.length &&
          !languageChanges[languageChangeIndex].when!.isAfter(m.sentAt)) {
        final change = languageChanges[languageChangeIndex++];
        items.add(
          _LanguageTimelineItem(
            languageCode: change.language!,
            topPadding: startsNewDate ? 0 : 10,
            bottomPadding: (10 - messageTopGap).clamp(0, 10).toDouble(),
          ),
        );
      }
      if (unreadMessageIds.isNotEmpty && m.id == unreadMessageIds.first) {
        items.add(_UnreadDividerItem(unreadMessageIds.length));
      }

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
      if (m.id == firstPendingId &&
          shouldShowPendingTranslationGroupStatus(pendingIncoming.length)) {
        items.add(_PendingTranslationStatusItem(pendingIncoming.length));
      }
    }
    while (languageChangeIndex < languageChanges.length) {
      final change = languageChanges[languageChangeIndex++];
      items.add(
        _LanguageTimelineItem(
          languageCode: change.language!,
          topPadding: 10,
          bottomPadding: 10,
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
        if (item is _UnreadDividerItem) {
          return _UnreadDivider(key: unreadDividerKey, count: item.count);
        }
        if (item is _PendingTranslationStatusItem) {
          return _PendingTranslationStatus(count: item.count);
        }
        if (item is _LanguageTimelineItem) {
          return _LanguageTimelineMarker(
            languageCode: item.languageCode,
            topPadding: item.topPadding,
            bottomPadding: item.bottomPadding,
          );
        }
        if (item is _MessageItem) {
          final era = eraForMessage(item.message);
          final replyEra = item.message.replyTo == null
              ? era
              : eraForMessage(item.message.replyTo!);
          return KeyedSubtree(
            key: messageAnchorKey(item.message.id),
            child: _MessageRow(
              chatId: chatId,
              partnerName: partnerName,
              message: item.message,
              reactions: reactionsByMessage[item.message.id] ?? const [],
              isFirstInGroup: item.isFirstInGroup,
              isLastInGroup: item.isLastInGroup,
              languageCode: era.languageCode,
              replyLanguageCode: replyEra.languageCode,
              translationInterfaceLanguageCode:
                  translationInterfaceLanguageCode,
              shouldTranslate: languageTimelineReady && !practiceSetupRequired,
              practiceSetupRequired: practiceSetupRequired,
              translationCutoffAt: null,
              popupTopInset: popupTopInset,
              deferTranslationResolve: deferTranslationResolve,
              holdIncomingUntilPrevious:
                  hasEarlierPending[item.message.id] ?? false,
              isSelected: selectedMessageId == item.message.id,
              showOriginal:
                  selectedMessageId == item.message.id && showSelectedOriginal,
              selectedBubbleKey: selectedMessageId == item.message.id
                  ? selectedBubbleKey
                  : null,
              onLongPress: (rect, position) =>
                  onLongPress(item.message, rect, position),
              onReply: () => onReply(item.message),
              onFailedTap: () => onFailedTap(item.message),
              onFailedRetry: () => onFailedRetry(item.message),
              onReact: () => onReact(item.message),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

String _capitaliseName(String name) =>
    name.isEmpty ? name : name[0].toUpperCase() + name.substring(1);

String _languageNameForCode(String? code) {
  if (code == null) return 'your language';
  for (final language in kBlabLanguages) {
    if (language.code == code) return language.name;
  }
  return 'your language';
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

sealed class _ListItem {
  const _ListItem();
}

class _DateDividerItem extends _ListItem {
  const _DateDividerItem(this.when);
  final DateTime when;
}

class _UnreadDividerItem extends _ListItem {
  const _UnreadDividerItem(this.count);
  final int count;
}

class _PendingTranslationStatusItem extends _ListItem {
  const _PendingTranslationStatusItem(this.count);
  final int count;
}

class _LanguageTimelineItem extends _ListItem {
  const _LanguageTimelineItem({
    required this.languageCode,
    required this.topPadding,
    required this.bottomPadding,
  });
  final String languageCode;
  final double topPadding;
  final double bottomPadding;
}

class _LanguageTimelineMarker extends StatelessWidget {
  const _LanguageTimelineMarker({
    required this.languageCode,
    required this.topPadding,
    required this.bottomPadding,
  });

  final String languageCode;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
      child: Center(
        child: Text(
          'Now learning ${_languageNameForCode(languageCode)}',
          style: const TextStyle(
            color: Color(0xFF8C735F),
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: BlabColors.textMuted,
            fontWeight: FontWeight.w500,
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

class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count == 1 ? '1 new message' : '$count new messages';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE1DAD2), height: 1)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              height: 1.25,
              color: BlabColors.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: Color(0xFFE1DAD2), height: 1)),
        ],
      ),
    );
  }
}

class _PendingTranslationStatus extends StatelessWidget {
  const _PendingTranslationStatus({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 2, bottom: 6),
        child: Text(
          count == 1 ? 'Translating…' : 'Translating $count messages…',
          style: const TextStyle(
            fontSize: 12,
            height: 1.25,
            color: BlabColors.textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── message row ─────────────────────────────────────

class _MessageRow extends ConsumerWidget {
  const _MessageRow({
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
    required this.holdIncomingUntilPrevious,
    required this.onLongPress,
    required this.onReply,
    required this.onFailedTap,
    required this.onFailedRetry,
    required this.onReact,
    required this.isSelected,
    required this.showOriginal,
    this.selectedBubbleKey,
  });

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
  /// [_MessageList.translationInterfaceLanguageCode].
  final String translationInterfaceLanguageCode;
  final bool shouldTranslate;
  final bool practiceSetupRequired;
  final DateTime? translationCutoffAt;
  final double popupTopInset;
  final bool deferTranslationResolve;
  final bool holdIncomingUntilPrevious;
  final void Function(Rect bubbleRect, Offset pressPosition) onLongPress;
  final VoidCallback onReply;
  final VoidCallback onFailedTap;
  final VoidCallback onFailedRetry;
  final VoidCallback onReact;
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
        isOut ||
        !canRequestTranslation ||
        translationEntry is AsyncData<MessageTranslation> ||
        translationEntry is AsyncError<MessageTranslation>;
    final readsNotifier = !isOut
        ? ref.read(messageReadsProvider(chatId).notifier)
        : null;

    // MessageInteractionTarget (long-press / swipe-reply gesture surface) is
    // wired here but applied inside _Bubble, around the bubble content only
    // — never around the practice-mode translate icon beside it. It measures
    // its own RenderBox to position the floating reaction row
    // (_selectedBubbleRect), so if it wrapped the icon+bubble Row too, that
    // rect would include the icon and throw off the row's horizontal
    // centering on every practice-mode long-press.
    Widget bubble = _Bubble(
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
      holdIncomingUntilPrevious: holdIncomingUntilPrevious,
      reactions: reactions,
      onReact: onReact,
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
        padding: EdgeInsets.fromLTRB(12, topGap, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
              child: bubble,
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends ConsumerStatefulWidget {
  const _Bubble({
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
    required this.holdIncomingUntilPrevious,
    required this.onReact,
    required this.isFailed,
    required this.onLongPress,
    required this.onFailedTap,
    required this.onFailedRetry,
    required this.isSelected,
    required this.showOriginal,
    this.onSwipeReply,
    this.selectedBubbleKey,
  });

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
  final bool holdIncomingUntilPrevious;

  /// [MessageInteractionTarget]'s gesture-surface inputs — applied inside
  /// this widget's build around the bubble content only (never around the
  /// practice-mode translate icon beside it), so the long-press rect it
  /// measures for the floating reaction row stays the bubble's true bounds.
  final bool isFailed;
  final void Function(Rect bubbleRect, Offset pressPosition) onLongPress;
  final VoidCallback onFailedTap;
  final VoidCallback onFailedRetry;
  final VoidCallback? onSwipeReply;
  final VoidCallback onReact;
  final bool isSelected;
  final bool showOriginal;
  final GlobalKey? selectedBubbleKey;

  @override
  ConsumerState<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends ConsumerState<_Bubble> {
  bool _incomingOriginalRevealedAfterFailure = false;
  bool _incomingWasHeld = false;
  int _openFormChoiceIndex = 0;

  @override
  void didUpdateWidget(covariant _Bubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id ||
        oldWidget.message.originalText != widget.message.originalText ||
        oldWidget.mode != widget.mode ||
        oldWidget.targetLanguageCode != widget.targetLanguageCode) {
      _incomingOriginalRevealedAfterFailure = false;
      _incomingWasHeld = false;
      _openFormChoiceIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formPreferences = ref.watch(
      grammaticalFormPreferencesProvider(widget.chatId),
    );

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
    final holdIncomingUntilPrevious = widget.holdIncomingUntilPrevious;
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
    if (!isOut && liveTranslation is AsyncError<MessageTranslation>) {
      _incomingOriginalRevealedAfterFailure = true;
    }
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
    );
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
    final snapshot = stored?.sourceText == message.originalText ? stored : null;
    final formChoices = resolvedTranslation?.formChoices ?? const [];
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
    if (formLedger != null &&
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
    final showLearningAid =
        shouldTranslate &&
        kSupportedLearningLanguages.contains(targetLanguageCode);
    Widget buildLearningContent({
      required AsyncValue<MessageTranslation>? translation,
      required bool showTranslation,
      bool pending = false,
    }) => MessageLearningContent(
      authoredText: message.originalText,
      translation: translation,
      showTranslation: showTranslation,
      learningLanguageCode: languageCode,
      isOutgoing: isOut,
      popupTopInset: popupTopInset,
      mode: mode,
      knownLanguageCodes: knownLanguageCodes,
      resolvedSourceLang: resolvedSourceLang,
      expanded: widget.isSelected && mode == ChatMode.practice,
      showOriginal: widget.isSelected && widget.showOriginal,
      pendingColor: pending
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

    final incomingProcessing =
        showLearningAid &&
        (holdIncomingUntilPrevious ||
            liveTranslation is! AsyncData<MessageTranslation>) &&
        liveTranslation is! AsyncError<MessageTranslation>;
    if (shouldHoldIncomingTranslation(
      isOutgoing: isOut,
      processing: incomingProcessing,
      originalWasRevealedAfterFailure: _incomingOriginalRevealedAfterFailure,
    )) {
      _incomingWasHeld = true;
    }

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
    final reducedMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    final retryingRevealedIncoming =
        !isOut &&
        _incomingOriginalRevealedAfterFailure &&
        showLearningAid &&
        liveTranslation is! AsyncError<MessageTranslation>;
    final pendingContent = !isOut && !retryingRevealedIncoming
        ? const IncomingTranslationPlaceholder()
        : authoredContent;
    final animateTranslationLifecycle =
        ((isOut && isPractice) || !isOut) &&
        showLearningAid &&
        liveTranslation is! AsyncError<MessageTranslation>;
    final messageLearningContent = animateTranslationLifecycle
        ? TranslatingMessageContent(
            key: ValueKey(
              'translation-lifecycle-$targetLanguageCode-'
              '${message.originalText.hashCode}',
            ),
            authoredContent: pendingContent,
            finalContent: finalContent,
            resolved: resolvedForLifecycle && !holdIncomingUntilPrevious,
            delivered:
                message.status == MessageStatus.delivered ||
                message.status == MessageStatus.read,
            unchanged: unchangedForLifecycle,
            reduceMotion: reducedMotion,
            outgoing: isOut,
            showAuthoredImmediately: retryingRevealedIncoming,
            deferResolve: widget.deferTranslationResolve,
            keepAuthoredDuringFastHold: isOut,
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
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Container(
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      border: Border.all(color: bubbleOutline),
                      borderRadius: radius,
                      boxShadow: isOut && isPractice
                          ? const [
                              BoxShadow(
                                color: Color(0x1A231208),
                                offset: Offset(0, 2),
                                blurRadius: 6,
                                spreadRadius: -2,
                              ),
                            ]
                          : null,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (replyTo != null) ...[
                          _QuotedReply(
                            replyTo: replyTo,
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
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (message.attachment != null) ...[
                          _PhotoAttachmentView(attachment: message.attachment!),
                          if (message.originalText.trim().isNotEmpty)
                            const SizedBox(height: 8),
                        ],
                        if (message.originalText.trim().isNotEmpty)
                          messageLearningContent,
                        if (isLastInGroup || message.isEdited) ...[
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
                if (showLearningAid &&
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
              // Reactions sit on the bubble edge nearest the conversation's
              // center: left for sent messages, right for received messages.
              left: isOut ? 14 : null,
              right: isOut ? null : 14,
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
          _incomingWasHeld ||
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
      onSwipeReply: onSwipeReply,
      child: bubbleStack,
    );
    final hasError = isFailed || presentation.translationFailed;
    final showUnsupportedLanguageHint =
        presentation.unsupportedSource && showLearningAid;
    final showReducedMotionProcessing =
        reducedMotion &&
        isOut &&
        isPractice &&
        showLearningAid &&
        liveTranslation is AsyncLoading<MessageTranslation> &&
        (message.status == MessageStatus.delivered ||
            message.status == MessageStatus.read);
    if (!hasError &&
        !showReducedMotionProcessing &&
        !showUnsupportedLanguageHint) {
      return interactiveBubble;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isOut
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        interactiveBubble,
        if (showReducedMotionProcessing)
          DelayedTranslationStatus(
            active: true,
            status: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                resolvedSourceLang == targetLanguageCode
                    ? context.l10n.checking
                    : context.l10n.translating,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  color: BlabColors.textMuted,
                ),
              ),
            ),
            idle: const SizedBox.shrink(),
          ),
        if (showUnsupportedLanguageHint)
          _UnsupportedLanguageNotice(
            key: const ValueKey('unsupported-language-hint'),
            text: context.l10n.unsupportedLanguageHint(
              _languageNameForCode(languageCode),
            ),
            alignRight: isOut,
          ),
        if (isFailed) ...[
          if (reactions.isEmpty) const SizedBox(height: 6),
          _MessageStatusNotice(
            key: const ValueKey('failed-message-retry'),
            text: context.l10n.failedToSend,
            onTap: onFailedRetry,
            alignRight: isOut,
          ),
        ],
        if (presentation.translationFailed) ...[
          if (!isFailed && reactions.isEmpty) const SizedBox(height: 6),
          if (isFailed) const SizedBox(height: 4),
          _MessageStatusNotice(
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

class _MessageStatusNotice extends StatelessWidget {
  const _MessageStatusNotice({
    super.key,
    required this.text,
    required this.onTap,
    required this.alignRight,
  });

  final String text;
  final VoidCallback? onTap;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Align(
      widthFactor: 1,
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Text(
            text,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              fontSize: 12,
              height: 1.25,
              fontWeight: FontWeight.w500,
              color: Color(0xFFC62828),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnsupportedLanguageNotice extends StatelessWidget {
  const _UnsupportedLanguageNotice({
    super.key,
    required this.text,
    required this.alignRight,
  });

  final String text;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    return Align(
      widthFactor: 1,
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          text,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            fontSize: 12,
            height: 1.25,
            fontWeight: FontWeight.w400,
            color: Color(0xFF917869),
          ),
        ),
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
        ? BlabColors.bubbleInk.withValues(alpha: 0.62)
        : BlabColors.textMuted;
    final children = <Widget>[
      Text(
        message.isEdited ? '${context.l10n.edited} · $timeLabel' : timeLabel,
        style: TextStyle(fontSize: 10, color: textColor),
      ),
    ];
    if (message.isOutgoing) {
      children.add(const SizedBox(width: 3));
      children.add(Text('·', style: TextStyle(fontSize: 10, color: textColor)));
      children.add(const SizedBox(width: 3));
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

final Map<String, _CachedAttachmentImage> _attachmentImageProviders =
    <String, _CachedAttachmentImage>{};

class _CachedAttachmentImage {
  const _CachedAttachmentImage({required this.kind, required this.provider});

  final String kind;
  final ImageProvider<Object> provider;
}

ImageProvider<Object>? _attachmentImageProvider(MessageAttachment attachment) {
  final cached = _attachmentImageProviders[attachment.id];
  final bytes = attachment.localBytes;
  if (bytes != null && bytes.isNotEmpty) {
    if (cached?.kind == 'full:${bytes.length}') return cached!.provider;
    final provider = MemoryImage(Uint8List.fromList(bytes));
    _attachmentImageProviders[attachment.id] = _CachedAttachmentImage(
      kind: 'full:${bytes.length}',
      provider: provider,
    );
    return provider;
  }

  final previewBytes = attachment.previewBytes;
  if (previewBytes != null && previewBytes.isNotEmpty) {
    if (cached?.kind == 'preview:${previewBytes.length}') {
      return cached!.provider;
    }
    final provider = MemoryImage(Uint8List.fromList(previewBytes));
    _attachmentImageProviders[attachment.id] = _CachedAttachmentImage(
      kind: 'preview:${previewBytes.length}',
      provider: provider,
    );
    return provider;
  }

  final url = attachment.url;
  if (url != null && url.isNotEmpty) {
    // Reuse the provider while the signed URL is unchanged. If the URL is
    // refreshed, create one new provider; gaplessPlayback keeps the old
    // frame visible until the refreshed image is ready.
    if (cached?.kind == 'network:$url') return cached!.provider;
    final provider = NetworkImage(url);
    _attachmentImageProviders[attachment.id] = _CachedAttachmentImage(
      kind: 'network:$url',
      provider: provider,
    );
    return provider;
  }

  return cached?.provider;
}

class _PhotoAttachmentView extends ConsumerWidget {
  const _PhotoAttachmentView({required this.attachment});

  final MessageAttachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = _attachmentImageProvider(attachment);
    final image = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 220,
        height: 220,
        child: provider == null
            ? const _OfflinePhotoPlaceholder()
            : Image(
                image: provider,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const _OfflinePhotoPlaceholder(),
              ),
      ),
    );
    return GestureDetector(
      onTap: provider == null
          ? null
          : () {
              // Keep the fast preview-first interaction, then persist the
              // full file once it has been opened. This also works when the
              // signed URL is unavailable: the already-cached preview still
              // opens without a framework error surface.
              unawaited(_cacheOpenedFullAttachment(ref, attachment));
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _PhotoPreviewScreen(imageProvider: provider),
                ),
              );
            },
      child: image,
    );
  }
}

/// Keeps a missing preview recognizable without exposing framework error UI.
/// The muted media glyph is decorative; the surrounding neutral surface keeps
/// the same geometry as a loaded photo (US-047 / FR-41).
class _OfflinePhotoPlaceholder extends StatelessWidget {
  const _OfflinePhotoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFFEAE6E0),
      child: Center(
        child: BlabIcon(
          name: 'media-image - 20',
          size: 24,
          color: Color(0x668C735F),
        ),
      ),
    );
  }
}

Future<void> _cacheOpenedFullAttachment(
  WidgetRef ref,
  MessageAttachment attachment,
) async {
  if (attachment.localBytes != null ||
      attachment.url == null ||
      attachment.url!.isEmpty) {
    return;
  }
  try {
    final response = await http.get(Uri.parse(attachment.url!));
    if (response.statusCode < 200 || response.statusCode >= 300) return;
    await ref
        .read(localChatHistoryCacheProvider)
        ?.saveAttachmentBytes(attachment.id, response.bodyBytes);
  } catch (_) {
    // Best effort only. The preview remains available for offline display.
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
    final tint = BlabColors.bubbleInk.withValues(alpha: 0.5);
    switch (status) {
      case MessageStatus.pending:
        return Semantics(
          label: context.l10n.sending,
          child: Icon(
            Icons.access_time,
            size: 16,
            color: isOutgoing ? tint : BlabColors.textMuted,
          ),
        );
      case MessageStatus.delivered:
        return Semantics(
          label: context.l10n.delivered,
          child: BlabIcon(
            name: 'check - 16',
            size: 16,
            color: isOutgoing ? tint : Colors.grey.shade500,
          ),
        );
      case MessageStatus.read:
        return Semantics(
          label: context.l10n.read,
          child: BlabIcon(
            name: 'double-check - 16',
            size: 16,
            color: isOutgoing ? tint : Colors.grey.shade500,
          ),
        );
      case MessageStatus.failed:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────── input ───────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.hintText,
    required this.textLength,
    required this.maxLength,
    required this.counterShowAt,
    required this.isPractice,
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
  final bool showTopBorder;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final bool allowAttachment;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final overLimit = textLength > maxLength;
    final canSend = hasText && !overLimit;
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
    required this.partnerName,
    required this.parentIsOutgoing,
    required this.translation,
    required this.mode,
    required this.knownLanguageCodes,
  });

  final Message replyTo;
  final String partnerName;
  final bool parentIsOutgoing;
  final AsyncValue<MessageTranslation>? translation;

  /// FR-23 / modes-known-languages spec: this preview follows the same
  /// three display rules as [MessageLearningContent] via
  /// [resolveMessageDisplayText] — a second message-rendering path that
  /// Task 9's rewrite didn't reach, fixed here rather than duplicated.
  final ChatMode mode;
  final List<String> knownLanguageCodes;

  @override
  Widget build(BuildContext context) {
    final tintBg = replyTo.isOutgoing
        ? const Color(0xFFFAB894)
        : const Color(0xFFF5F0E8);
    final barColor = replyTo.isOutgoing
        ? BlabColors.brand
        : BlabColors.avatarColorFor(partnerName);
    final labelColor = barColor;
    final previewColor = parentIsOutgoing
        ? BlabColors.bubbleInk.withValues(alpha: 0.78)
        : BlabColors.textMuted;

    final author = replyTo.isOutgoing ? context.l10n.you : partnerName;
    final rawPreviewText = switch (translation) {
      AsyncData<MessageTranslation>(value: final value) =>
        resolveMessageDisplayText(
          authoredText: replyTo.originalText,
          value: value,
          mode: mode,
          knownLanguageCodes: knownLanguageCodes,
        ),
      _ => replyTo.originalText,
    };
    final previewText =
        rawPreviewText.trim().isEmpty && replyTo.attachment != null
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
            : Image(image: provider, fit: BoxFit.cover, gaplessPlayback: true),
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
    final whose = message.isOutgoing ? context.l10n.you : partnerName;
    final accent = message.isOutgoing
        ? BlabColors.brand
        : BlabColors.avatarColorFor(partnerName);
    final attachment = message.attachment;
    final previewText =
        message.originalText.trim().isEmpty && attachment != null
        ? context.l10n.photoMessagePreview
        : message.originalText;
    return Container(
      decoration: const BoxDecoration(
        color: BlabColors.chatSurface,
        border: Border(top: BorderSide(color: BlabColors.chatDivider)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 3,
              height: 38,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 9),
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
                    whose,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accent,
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
            SizedBox(
              width: 44,
              child: Center(
                child: InkWell(
                  onTap: onClose,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: BlabColors.textMuted,
                    ),
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

// ─────────────────────────── edit bar ────────────────────────────────────────

/// Centered exchange card shown in any chat with no messages yet.
/// PRD US-027.
class _EditBar extends StatelessWidget {
  const _EditBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: BlabColors.chatSurface,
      padding: const EdgeInsets.fromLTRB(14, 8, 12, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.editingMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BlabColors.brand,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              child: Center(
                child: InkWell(
                  onTap: onClose,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: BlabColors.textMuted,
                    ),
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
