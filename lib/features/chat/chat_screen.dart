import '../../shared/widgets/surfaces/blab_confirmation_dialog.dart';
import 'dart:math' as math;
import '../../shared/widgets/surfaces/blab_dialog.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../app/app_messenger.dart';
import '../../app/telegram_route.dart';
import '../../app/theme.dart';
import '../../shared/widgets/actions/blab_icon_button.dart';
import 'widgets/message_bubble_surface.dart';
import '../../shared/widgets/blab_avatar.dart';
import '../../shared/widgets/navigation/blab_app_bar.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/chat.dart';
import '../../shared/data/languages.dart';
import '../../shared/models/message.dart';
import '../../shared/models/message_reaction.dart';
import '../../shared/models/reading_script.dart';
import '../../shared/services/chat_service.dart';
import '../../shared/services/local_chat_history_cache.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/state/connectivity_state.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/skeletons.dart';
import '../../shared/data/translation_support.dart';
import '../../shared/data/local_storage_keys.dart';
import '../../shared/services/message_translator.dart';
import '../../shared/services/tts_service.dart';
import '../../shared/state/interface_language.dart';
import '../../shared/state/known_languages_state.dart';
import '../../shared/state/push_notifications_state.dart';
import '../../shared/state/reading_script_state.dart';
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
import 'widgets/blocked_chat_bar.dart';
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
import 'partner_profile_page.dart';
import 'widgets/photo_preview_sheet.dart';
import 'widgets/report_sheet.dart';
import 'widgets/translating_message_content.dart';

part 'widgets/chat_header.dart';
part 'widgets/chat_menu.dart';
part 'widgets/chat_timeline.dart';
part 'widgets/message_row.dart';
part 'widgets/message_bubble.dart';
part 'widgets/message_meta.dart';
part 'widgets/photo_message.dart';
part 'widgets/message_delivery_status.dart';
part 'widgets/chat_composer.dart';
part 'widgets/reply_preview.dart';
part 'widgets/composer_context_bar.dart';

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

enum ChatModeTip { practice, normal }

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _bottomSurfaceKey = GlobalKey();
  final GlobalKey _selectedBubbleKey = GlobalKey();
  final GlobalKey _unreadDividerKey = GlobalKey();
  final Map<String, GlobalKey> _messageAnchorKeys = <String, GlobalKey>{};
  String? _replyHighlightId;
  Timer? _replyHighlightTimer;
  final _chatMenuController = MenuController();
  final _modeControlKey = GlobalKey();
  bool _hasText = false;
  int _textLength = 0;
  double _lastBottomInset = 0;
  bool _translationResolveDeferred = false;
  int _lastMessageCount = 0;
  Message? _selectedMessage;
  Message? _reactionRowMessage;
  Rect? _selectedBubbleRect;
  Offset? _selectedPressPosition;
  bool _showSelectedOriginal = false;
  Timer? _reactionRowDismissTimer;

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
  ChatModeTip? _visibleModeTip;
  int _modeAnchorGeneration = 0;
  Timer? _modeAnchorTimer;
  bool _jumpingToReply = false;

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
    _ready = Future<void>.value();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _modeAnchorTimer?.cancel();
    _replyHighlightTimer?.cancel();
    _reactionRowDismissTimer?.cancel();
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
        await _showModeTipOnce(ChatModeTip.practice);
      } finally {
        _requiredLanguageSheetVisible = false;
      }
    });
  }

  Future<void> _showModeTipOnce(ChatModeTip tip) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final preferences = await SharedPreferences.getInstance();
    final key = modeTipSeenStorageKey(userId: userId, mode: tip.name);
    if (preferences.getBool(key) == true || !mounted) return;
    await preferences.setBool(key, true);
    await WidgetsBinding.instance.endOfFrame;
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
          final visibleHeight =
              (bottom.clamp(viewportTop, viewportBottom) -
              top.clamp(viewportTop, viewportBottom));
          final meaningfulHeight = render.size.height * 0.5 < 44
              ? render.size.height * 0.5
              : 44.0;
          if (visibleHeight >= meaningfulHeight) {
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
    final generation = ++_modeAnchorGeneration;
    _modeAnchorTimer?.cancel();
    var seekSteps = 0;
    void restore() {
      if (!mounted ||
          !_scroll.hasClients ||
          generation != _modeAnchorGeneration) {
        return;
      }
      final next = _scroll.position;
      if (_modeAnchorAtBottom) {
        next.jumpTo(0);
        return;
      }
      final render = _messageAnchorKeys[_modeAnchorMessageId]?.currentContext
          ?.findRenderObject();
      if (render is! RenderBox &&
          _modeAnchorMessageId != null &&
          seekSteps++ < 30) {
        final messages =
            ref.read(chatMessagesProvider(widget.chatId)).value ??
            const <Message>[];
        final targetIndex = messages.indexWhere(
          (m) => m.id == _modeAnchorMessageId,
        );
        final builtIndices = <int>[
          for (var i = 0; i < messages.length; i++)
            if (_messageAnchorKeys[messages[i].id]?.currentContext != null) i,
        ];
        if (targetIndex >= 0 && builtIndices.isNotEmpty) {
          final middle = builtIndices[builtIndices.length ~/ 2];
          final direction = targetIndex < middle ? 1 : -1;
          final offset =
              (next.pixels + direction * next.viewportDimension * 0.6).clamp(
                0.0,
                next.maxScrollExtent,
              );
          if (offset != next.pixels) {
            next.jumpTo(offset);
            WidgetsBinding.instance.addPostFrameCallback((_) => restore());
            return;
          }
        }
      }
      final viewport = next.context.storageContext.findRenderObject();
      if (render is RenderBox &&
          viewport is RenderBox &&
          _modeAnchorOffset != null) {
        final actualOffset =
            render.localToGlobal(Offset.zero).dy -
            viewport.localToGlobal(Offset.zero).dy;
        final delta = actualOffset - _modeAnchorOffset!;
        final sign = next.axisDirection == AxisDirection.up ? -1.0 : 1.0;
        next.jumpTo(
          (next.pixels + sign * delta).clamp(0.0, next.maxScrollExtent),
        );
      } else {
        next.jumpTo(fallbackOffset.clamp(0.0, next.maxScrollExtent));
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      restore();
      // Cached text can finish its measured layout after the mode frame.
      _modeAnchorTimer = Timer(const Duration(milliseconds: 350), restore);
    });
  }

  void _handleChatBack() {
    if (_chatMenuController.isOpen) {
      _chatMenuController.close();
      return;
    }
    if (_selectedMessage != null) {
      _closeSelection();
      return;
    }
    if (ref.read(replyingToProvider(widget.chatId)) != null) {
      ref.read(replyingToProvider(widget.chatId).notifier).clear();
      _inputFocus.unfocus();
      return;
    }
    _inputFocus.unfocus();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/chats');
    }
  }

  void _beginReply(Message message, {String? displayedText}) {
    if (ref.read(editingProvider(widget.chatId)) != null) return;
    _closeSelection();
    if (displayedText == null) {
      final known = ref.read(knownLanguagesProvider).value;
      final mode = ref.read(chatModeProvider(widget.chatId));
      final era = languageEraForMessage(
        sentAt: message.sentAt,
        timeline: parseChatLanguageTimeline(
          ref.read(chatLanguageTimelineProvider(widget.chatId)).value ?? [],
        ),
        fallbackLanguageCode: ref
            .read(learningLanguageProvider(widget.chatId))
            .code,
      );
      final target = known == null
          ? ''
          : resolveTranslationTarget(
              mode: mode,
              learningLanguageCode: era.languageCode,
              primaryKnownLanguageCode: known.primary,
            );
      final entry = ref.read(
        messageTranslationsProvider(widget.chatId),
      )[translationEntryKey(message.id, target, known?.primary ?? '')];
      displayedText = resolveMessagePresentation(
        authoredText: message.originalText,
        translation: entry?.whenData(
          (v) =>
              (ref.read(formCorrectionProvider).asData?.value ??
                      const FormCorrectionLedger())
                  .resolveTranslation(
                    v,
                    chatId: widget.chatId,
                    messageId: message.id,
                    targetLang: target,
                    sourceText: message.originalText,
                  ),
        ),
        mode: mode,
        knownLanguageCodes: known?.codes ?? [],
        targetLanguageCode: target,
        readingScript: ref.read(readingScriptProvider),
      ).primaryText;
    }
    ref
        .read(replyingToProvider(widget.chatId).notifier)
        .set(message.copyWith(originalText: displayedText));
    HapticFeedback.selectionClick();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _inputFocus.requestFocus();
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    });
  }

  Future<void> _jumpToQuotedMessage(Message target) async {
    if (_jumpingToReply || target.chatId != widget.chatId) return;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    _jumpingToReply = true;
    _modeAnchorGeneration++;
    _closeSelection();
    _inputFocus.unfocus();
    try {
      final notifier = ref.read(chatMessagesProvider(widget.chatId).notifier);
      for (var page = 0; page < 100; page++) {
        final messages =
            ref.read(chatMessagesProvider(widget.chatId)).value ??
            const <Message>[];
        if (messages.any((m) => m.id == target.id)) break;
        if (!ref.read(chatPaginationProvider(widget.chatId)).hasMore) return;
        final before = messages.length;
        await notifier.loadOlder();
        if (!mounted ||
            (ref.read(chatMessagesProvider(widget.chatId)).value?.length ??
                    0) <=
                before) {
          return;
        }
      }
      for (var step = 0; step < 100 && mounted && _scroll.hasClients; step++) {
        final targetContext = _messageAnchorKeys[target.id]?.currentContext;
        if (targetContext != null) {
          if (!targetContext.mounted) return;
          await Scrollable.ensureVisible(
            targetContext,
            alignment: 0.35,
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
          );
          if (!mounted) return;
          _replyHighlightTimer?.cancel();
          setState(() => _replyHighlightId = target.id);
          _replyHighlightTimer = Timer(const Duration(seconds: 1), () {
            if (mounted) setState(() => _replyHighlightId = null);
          });
          return;
        }
        final messages =
            ref.read(chatMessagesProvider(widget.chatId)).value ??
            const <Message>[];
        final targetIndex = messages.indexWhere((m) => m.id == target.id);
        if (targetIndex < 0) return;
        final visibleIndex = messages.indexWhere(
          (m) => _messageAnchorKeys[m.id]?.currentContext != null,
        );
        final direction = visibleIndex < 0 || targetIndex < visibleIndex
            ? 1
            : -1;
        final position = _scroll.position;
        final next =
            (position.pixels + direction * position.viewportDimension * 0.75)
                .clamp(0.0, position.maxScrollExtent);
        if (next == position.pixels) return;
        position.jumpTo(next);
        await WidgetsBinding.instance.endOfFrame;
      }
    } finally {
      _jumpingToReply = false;
    }
  }

  GlobalKey _messageAnchorKey(String messageId) =>
      _messageAnchorKeys.putIfAbsent(messageId, GlobalKey.new);

  void _anchorOldestUnread() {
    if (!mounted || _unreadDividerAnchored) return;
    final messages =
        ref.read(chatMessagesProvider(widget.chatId)).value ??
        const <Message>[];
    final unread =
        messages
            .where((message) => _sessionUnreadIds.contains(message.id))
            .toList()
          ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
    if (unread.isEmpty) return;
    final context = _messageAnchorKeys[unread.first.id]?.currentContext;
    if (context == null) return;
    _unreadDividerAnchored = true;
    unawaited(
      Scrollable.ensureVisible(context, alignment: 1, duration: Duration.zero),
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
      showAppSnack(context.l10n.couldNotOpenPhotos);
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
      showAppSuccessSnack(
        successMessage,
        bottomClearance: _activeBottomSurfaceHeight,
      );
    } catch (_) {
      showAppSnack(errorMessage);
    }
  }

  Future<void> _unblockPartner(Chat chat) async {
    final success = context.l10n.personUnblocked(chat.partnerName);
    final failure = context.l10n.couldNotUnblock;
    try {
      await ref.read(chatServiceProvider).unblockUser(chat.partnerId!);
      showAppSuccessSnack(success, bottomClearance: _activeBottomSurfaceHeight);
    } catch (_) {
      showAppSnack(failure);
    }
  }

  double get _activeBottomSurfaceHeight {
    final renderObject = _bottomSurfaceKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.size.height;
    }
    return 0;
  }

  Future<void> _confirmDelete(Message message, Chat chat) async {
    final confirmed = await showBlabDialog<bool>(
      context: context,
      builder: (dialogContext) => BlabConfirmationDialog(
        backgroundColor: BlabColors.chatSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
          side: BorderSide(color: BlabColors.chatDivider),
        ),
        title: Text(
          context.l10n.deleteMessageQuestion,
          style: const TextStyle(color: BlabColors.warmInk),
        ),
        content: Text(
          context.l10n.deleteMessageBody(chat.partnerName),
          style: const TextStyle(color: BlabColors.warmMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              context.l10n.cancel,
              style: const TextStyle(color: BlabColors.warmInk),
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
        _beginReply(message, displayedText: presentation.primaryText);
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

  void _toggleMenu() {
    if (_chatMenuController.isOpen) {
      _chatMenuController.close();
    } else {
      _chatMenuController.open();
    }
  }

  void _closeMenu() => _chatMenuController.close();

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
    _reactionRowDismissTimer?.cancel();
    setState(() {
      _selectedMessage = message;
      _reactionRowMessage = message;
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
    _reactionRowDismissTimer?.cancel();
    setState(() {
      _selectedMessage = null;
      _showSelectedOriginal = false;
    });
    _reactionRowDismissTimer = Timer(kFloatingReactionRowExitDuration, () {
      if (!mounted || _selectedMessage != null) return;
      setState(() {
        _reactionRowMessage = null;
        _selectedBubbleRect = null;
        _selectedPressPosition = null;
      });
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
    final blockedUserIds =
        ref.watch(blockedUserIdsProvider).value ?? const <String>{};
    final isPartnerBlocked =
        chat.partnerId != null && blockedUserIds.contains(chat.partnerId);
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
    final historyUnavailable =
        messagesAsync.value == null && messagesAsync.hasError;
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
    final readingScript = ref.watch(readingScriptProvider);
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
        targetLanguageCode: selectedTargetLang,
        readingScript: readingScript,
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
        '$translationInterfaceLang|${learningLang.code}|$timelineKey|${chat.needsPracticeLanguageSelection}';
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
        // Hydrate persisted results for both views, without generating them.
        // Switching mode is a local presentation change, not a cache reset.
        final targets =
            chat.needsPracticeLanguageSelection || knownLanguages == null
            ? <String>{}
            : {era.languageCode, knownLanguages.primary};
        for (final candidateTarget in targets) {
          if (!shouldRequestBubbleTranslation(
            targetLanguageCode: candidateTarget,
            text: candidate.originalText,
            sentAt: candidate.sentAt,
            translationCutoffAt: null,
          )) {
            continue;
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
          retryMisses: target == targetLang,
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
      final cancelReplyOnBack =
          bottomInset == 0 &&
          _lastBottomInset > 0 &&
          _inputFocus.hasFocus &&
          replyingTo != null;
      _lastBottomInset = bottomInset;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (cancelReplyOnBack) {
          ref.read(replyingToProvider(widget.chatId).notifier).clear();
        }
        if (keyboardAppeared) _closeSelection();
        if (!_scroll.hasClients) return;
        if (_scroll.position.pixels > 200) return;
        _scrollToBottom();
      });
    }

    final practiceHint = chatMode == ChatMode.practice
        ? context.l10n.practiceComposerHint(
            localizedLanguageName(context.l10n, learningLang.code),
            localizedLanguageName(
              context.l10n,
              knownLanguages?.primary ?? 'en',
            ),
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
      canPop:
          !_chatMenuController.isOpen &&
          _selectedMessage == null &&
          replyingTo == null &&
          !chat.needsPracticeLanguageSelection &&
          Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleChatBack();
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
                  ChatHeader(
                    chat: chat,
                    onBeforeModeToggle: _captureModeAnchor,
                    onModeChanged: (mode) {
                      if (mode == ChatMode.normal) {
                        unawaited(_showModeTipOnce(ChatModeTip.normal));
                      }
                    },
                    practiceSetupRequired: chat.needsPracticeLanguageSelection,
                    menuController: _chatMenuController,
                    modeControlKey: _modeControlKey,
                    onMenuStateChanged: () {
                      if (mounted) setState(() {});
                    },
                    onLearningLanguageTap: () async {
                      _closeMenu();
                      final current = ref.read(
                        learningLanguageProvider(widget.chatId),
                      );
                      await showLearningLanguageSheet(
                        context,
                        current: current,
                        onSelected: (language) => ref
                            .read(
                              learningLanguageProvider(widget.chatId).notifier,
                            )
                            .set(language),
                      );
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

                    selectionActive: _selectedMessage != null,
                    onDismissSelection: _closeSelection,
                    onBack: _handleChatBack,
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
                      await showPartnerProfilePage(context, chat: chat);
                      if (!context.mounted) return;
                      final blockedIds =
                          ref.read(blockedUserIdsProvider).value ??
                          const <String>{};
                      if (blockedIds.contains(chat.partnerId)) {
                        ref
                            .read(replyingToProvider(widget.chatId).notifier)
                            .clear();
                        ref
                            .read(editingProvider(widget.chatId).notifier)
                            .clear();
                        _inputFocus.unfocus();
                      } else if (editing != null) {
                        _inputFocus.requestFocus();
                      }
                    },
                  ),
                  if (pushNotifications.reminderVisible)
                    ChatNotificationReminder(
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
                          if (isUserDrag) _modeAnchorGeneration++;
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
                            final pending = ref.watch(
                              pendingSendsProvider(widget.chatId),
                            );
                            if (knownMessages == null && pending.isEmpty) {
                              if (messagesAsync.hasError) {
                                return ChatHistoryErrorState(
                                  onRetry: () => ref.invalidate(
                                    chatMessagesProvider(widget.chatId),
                                  ),
                                );
                              }
                              return const ChatViewSkeleton();
                            }
                            return Builder(
                              builder: (context) {
                                final messages =
                                    knownMessages ?? const <Message>[];
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
                                return ChatTimeline(
                                  highlightedMessageId: _replyHighlightId,
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
                                      chatHeaderHeightFor(context),
                                  selectedMessageId: _selectedMessage?.id,
                                  showSelectedOriginal: _showSelectedOriginal,
                                  selectedBubbleKey: _selectedBubbleKey,
                                  emptyState: FirstMessageEmptyState(
                                    chat: chat,
                                  ),
                                  onLongPress: _selectMessage,
                                  onReply: _beginReply,
                                  onJumpToMessage: _jumpToQuotedMessage,
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
                  if (!isPartnerBlocked && replyingTo != null)
                    ComposerReplyBar(
                      message: replyingTo,
                      partnerName: chat.partnerName,
                      onClose: () => ref
                          .read(replyingToProvider(widget.chatId).notifier)
                          .clear(),
                    ),
                  if (!isPartnerBlocked && editing != null)
                    ComposerEditBar(
                      onClose: () => ref
                          .read(editingProvider(widget.chatId).notifier)
                          .clear(),
                    ),
                  KeyedSubtree(
                    key: _bottomSurfaceKey,
                    child: _selectedMessage != null
                        ? MessageActionRow(
                            message: _selectedMessage!,
                            mode: chatMode,
                            hasOriginal: activePresentation.canRevealOriginal,
                            canListen:
                                activePresentation.listenText != null &&
                                hasSpeakableText(
                                  activePresentation.listenText!,
                                ),
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
                        : isPartnerBlocked
                        ? BlockedChatBar(
                            message: context.l10n.youBlockedPerson(
                              chat.partnerName,
                            ),
                            actionLabel: context.l10n.unblock,
                            onUnblock: () => unawaited(_unblockPartner(chat)),
                          )
                        : AbsorbPointer(
                            absorbing:
                                chat.needsPracticeLanguageSelection ||
                                historyUnavailable,
                            child: Opacity(
                              opacity:
                                  chat.needsPracticeLanguageSelection ||
                                      historyUnavailable
                                  ? .45
                                  : 1,
                              child: ChatComposer(
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
                                enabled:
                                    !chat.needsPracticeLanguageSelection &&
                                    !historyUnavailable,
                                showTopBorder: replyingTo == null,
                                onAttach: () => _attachImage(
                                  recipientName: chat.partnerName,
                                ),
                                onSend: _send,
                                autofocus:
                                    chatIsEmpty ||
                                    replyingTo != null ||
                                    editing != null,
                                allowAttachment: editing == null,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
              if (_visibleModeTip != null)
                Positioned(
                  top:
                      MediaQuery.paddingOf(context).top +
                      chatHeaderHeightFor(context) +
                      8,
                  right: 16,
                  child: TapRegion(
                    onTapOutside: (_) => setState(() => _visibleModeTip = null),
                    child: ChatModeTipCard(
                      tip: _visibleModeTip!,
                      modeControlKey: _modeControlKey,
                      practiceLanguage: localizedLanguageName(
                        context.l10n,
                        learningLang.code,
                      ),
                      primaryKnownLanguage: localizedLanguageName(
                        context.l10n,
                        knownLanguages?.primary ?? 'en',
                      ),
                      onDismiss: () => setState(() => _visibleModeTip = null),
                      onEditKnownLanguages: () {
                        setState(() => _visibleModeTip = null);
                        context.push('/profile/known-languages');
                      },
                    ),
                  ),
                ),
              if (_reactionRowMessage != null &&
                  _selectedBubbleRect != null &&
                  _selectedPressPosition != null &&
                  canReplyToMessage(_reactionRowMessage!))
                Builder(
                  builder: (_) {
                    final reactionRowMessage = _reactionRowMessage!;
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
                        key: ValueKey(
                          'floating-reaction-row-${reactionRowMessage.id}',
                        ),
                        visible: _selectedMessage?.id == reactionRowMessage.id,
                        scaleAlignment: reactionRowMessage.isOutgoing
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        selectedEmoji: _viewerReactionEmoji(
                          reactionRowMessage.id,
                        ),
                        onPick: (emoji) {
                          final message = reactionRowMessage;
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
                          final message = reactionRowMessage;
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

/// Let large translated mode labels reflow without clipping the native toolbar.
bool chatHeaderIsStacked(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1) > 1.5 ||
    (MediaQuery.sizeOf(context).width <= 340 &&
        Localizations.localeOf(context).languageCode == 'uk');

double chatHeaderIdentityHeightFor(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context);
  return math.max(56, scale.scale(15) * 1.2 + scale.scale(12) * 1.43 + 1);
}

double chatHeaderHeightFor(BuildContext context) {
  if (!chatHeaderIsStacked(context)) return kChatHeaderHeight;
  final scale = MediaQuery.textScalerOf(context);
  final width = MediaQuery.sizeOf(context).width - 104;
  double labelHeight(String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: scale,
    )..layout(maxWidth: width);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  return chatHeaderIdentityHeightFor(context) +
      math.max(
        48,
        math.max(
              labelHeight(context.l10n.normalMode),
              labelHeight(context.l10n.practiceMode),
            ) +
            8,
      );
}
