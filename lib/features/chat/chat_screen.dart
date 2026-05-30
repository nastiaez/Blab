import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/models/chat.dart';
import '../../shared/models/message.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/state/connectivity_state.dart';
import '../../shared/widgets/offline_banner.dart';
import '../../shared/widgets/skeletons.dart';
import '../invite/widgets/exchange_card.dart';
import 'state/chat_state.dart';
import 'widgets/learning_language_sheet.dart';
import 'widgets/message_action_sheet.dart';
import 'widgets/message_text.dart';
import 'widgets/partner_profile_sheet.dart';

/// PRD US-013, US-014, US-015, US-016, US-017, US-023.
///
/// Mock-only chat surface. Header / messages list / input. Word popups,
/// long-press actions and the change-language sheet land in Steps 1.6–1.8.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _menuOpen = false;
  bool _hasText = false;
  int _textLength = 0;

  /// Hard cap from PRD US-036.
  static const int _maxMessageLength = 2000;

  /// Show the live character counter once we cross this threshold.
  static const int _counterShowAt = 1800;

  /// Cold-open skeleton gate. PRD US-032.
  late final Future<void> _ready;

  /// Tracks the id of the message currently being edited, so we can react to
  /// edit-mode being entered/exited and pre-fill / clear the text field
  /// accordingly. PRD US-019.
  String? _editingMessageId;

  @override
  void initState() {
    super.initState();
    _input.addListener(() {
      final text = _input.text;
      final has = text.trim().isNotEmpty;
      final len = text.characters.length;
      if (has != _hasText || len != _textLength) {
        setState(() {
          _hasText = has;
          _textLength = len;
        });
      }
    });
    _ready = Future<void>.delayed(const Duration(milliseconds: 400));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  void _send() {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    // Defensive — TextField.maxLength enforces this, but guard anyway.
    // PRD US-036.
    if (text.characters.length > _maxMessageLength) return;

    final editing = ref.read(editingProvider(widget.chatId));
    if (editing != null) {
      ref
          .read(chatMessagesProvider(widget.chatId).notifier)
          .editMessage(editing.id, text);
      ref.read(editingProvider(widget.chatId).notifier).clear();
      _input.clear();
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

  void _handleAction(Message message, MessageAction action) {
    switch (action) {
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
          const SnackBar(
            content: Text('Copied'),
            duration: Duration(milliseconds: 1500),
          ),
        );
        break;
      case MessageAction.delete:
        final notifier =
            ref.read(chatMessagesProvider(widget.chatId).notifier);
        final removedId = message.id;
        notifier.removeMessage(removedId);
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Message deleted'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Undo',
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

  @override
  Widget build(BuildContext context) {
    final chatListAsync = ref.watch(chatListProvider);
    final chat = chatListAsync.maybeWhen(
      data: (chats) {
        for (final c in chats) {
          if (c.id == widget.chatId) return c;
        }
        return null;
      },
      orElse: () => null,
    );

    if (chat == null) {
      return const Scaffold(
        backgroundColor: BlabColors.appBackground,
        body: SafeArea(child: ChatViewSkeleton()),
      );
    }

    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));
    final showTransl = ref.watch(showTranslationsProvider(widget.chatId));
    final replyingTo = ref.watch(replyingToProvider(widget.chatId));
    final editing = ref.watch(editingProvider(widget.chatId));
    final learningLang = ref.watch(learningLanguageProvider(widget.chatId));

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

    // Auto-scroll on message append.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients &&
          _scroll.position.pixels < _scroll.position.maxScrollExtent - 200) {
        return;
      }
      _scrollToBottom();
    });

    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Stack(
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
                  onTapPartner: () =>
                      showPartnerProfileSheet(context, chat: chat),
                ),
                const OfflineBanner(),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _closeMenu,
                    child: FutureBuilder<void>(
                      future: _ready,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState !=
                            ConnectionState.done) {
                          return const ChatViewSkeleton();
                        }
                        return messagesAsync.when(
                          loading: () => const ChatViewSkeleton(),
                          error: (_, _) => const ChatViewSkeleton(),
                          data: (messages) => _MessageList(
                            messages: messages,
                            showTranslations: showTransl,
                            scrollController: _scroll,
                            languageCode: learningLang.code,
                            // BUG-009: keep the word popup from drawing on
                            // top of the chat header. Account for the
                            // safe-area notch as well.
                            popupTopInset: MediaQuery.paddingOf(context).top +
                                kChatHeaderHeight,
                            emptyState: _FirstMessageEmptyState(chat: chat),
                            onLongPress: (m) {
                              HapticFeedback.mediumImpact();
                              showMessageActionSheet(
                                context,
                                message: m,
                                onAction: (a) => _handleAction(m, a),
                              );
                            },
                          ),
                        );
                      },
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
                _InputBar(
                  controller: _input,
                  hasText: _hasText,
                  hintText: 'English or ${learningLang.name}…',
                  textLength: _textLength,
                  maxLength: _maxMessageLength,
                  counterShowAt: _counterShowAt,
                  onSend: _send,
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
                top: kChatHeaderHeight - 4,
                right: 8,
                child: _ChatMenu(
                  chatId: widget.chatId,
                  onLearningLanguageTap: () async {
                    _closeMenu();
                    final current =
                        ref.read(learningLanguageProvider(widget.chatId));
                    final picked = await showLearningLanguageSheet(
                      context,
                      current: current,
                    );
                    if (picked != null) {
                      ref
                          .read(learningLanguageProvider(widget.chatId).notifier)
                          .set(picked);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── header ──────────────────────────────────────────

const double kChatHeaderHeight = 60;

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
    // BUG-007: hide the green dot + "Online" label when the device is
    // offline — the offline banner is the source of truth for live state.
    final onlineAsync = ref.watch(onlineProvider);
    final isOnline = onlineAsync.maybeWhen(
      data: (v) => v,
      orElse: () => true,
    );
    return Container(
      height: kChatHeaderHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 20,
              color: BlabColors.brand,
            ),
            onPressed: onBack,
            splashRadius: 22,
          ),
          Expanded(
            child: InkWell(
              onTap: onTapPartner,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    _HeaderAvatar(initial: chat.partnerInitial),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              chat.partnerName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: BlabColors.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOnline) ...[
                            const SizedBox(width: 8),
                            Semantics(
                              label: 'Online',
                              container: true,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    '●',
                                    style: TextStyle(
                                      color: Color(0xFF34C759),
                                      fontSize: 8,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Online',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: BlabColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Chat menu',
            icon: const Icon(Icons.more_horiz, size: 22),
            color: BlabColors.textMuted,
            onPressed: onMenu,
            splashRadius: 22,
          ),
        ],
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({required this.initial});
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
  const _ChatMenu({
    required this.chatId,
    required this.onLearningLanguageTap,
  });

  final String chatId;
  final VoidCallback onLearningLanguageTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTransl = ref.watch(showTranslationsProvider(chatId));
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Show translations',
                      style: TextStyle(
                        fontSize: 15,
                        color: BlabColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Switch(
                      value: showTransl,
                      activeThumbColor: Colors.white,
                      activeTrackColor: BlabColors.brand,
                      onChanged: (_) => ref
                          .read(showTranslationsProvider(chatId).notifier)
                          .toggle(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              InkWell(
                onTap: onLearningLanguageTap,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Learning language',
                        style: TextStyle(
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
    required this.messages,
    required this.showTranslations,
    required this.scrollController,
    required this.languageCode,
    required this.popupTopInset,
    required this.onLongPress,
    this.emptyState,
  });

  final List<Message> messages;
  final bool showTranslations;
  final ScrollController scrollController;
  final String languageCode;
  final double popupTopInset;
  final void Function(Message) onLongPress;
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

      final isFirstInGroup = prev == null ||
          prev.isOutgoing != m.isOutgoing ||
          !_isSameDay(prev.sentAt, m.sentAt) ||
          m.sentAt.difference(prev.sentAt).inMinutes.abs() > 2;
      final isLastInGroup = next == null ||
          next.isOutgoing != m.isOutgoing ||
          !_isSameDay(next.sentAt, m.sentAt) ||
          next.sentAt.difference(m.sentAt).inMinutes.abs() > 2;

      items.add(_MessageItem(
        message: m,
        isFirstInGroup: isFirstInGroup,
        isLastInGroup: isLastInGroup,
      ));
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        if (item is _DateDividerItem) {
          return _DateDivider(when: item.when);
        }
        if (item is _MessageItem) {
          return _MessageRow(
            message: item.message,
            showTranslation: showTranslations,
            isFirstInGroup: item.isFirstInGroup,
            isLastInGroup: item.isLastInGroup,
            languageCode: languageCode,
            popupTopInset: popupTopInset,
            onLongPress: () => onLongPress(item.message),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
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
    final label = _formatDay(when);
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

  static String _formatDay(DateTime when) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(when.year, when.month, when.day);
    final diffDays = today.difference(that).inDays;
    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';
    if (diffDays < 7) {
      const names = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return names[when.weekday - 1];
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[when.month - 1]} ${when.day}';
  }
}

// ─────────────────────────── message row ─────────────────────────────────────

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.showTranslation,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    required this.languageCode,
    required this.popupTopInset,
    required this.onLongPress,
  });

  final Message message;
  final bool showTranslation;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final String languageCode;
  final double popupTopInset;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final isOut = message.isOutgoing;
    final topGap = isFirstInGroup ? 10.0 : 2.0;
    final width = MediaQuery.sizeOf(context).width;
    final maxBubble = width * 0.78;

    final bubble = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onLongPress,
      child: _Bubble(
        message: message,
        showTranslation: showTranslation,
        maxWidth: maxBubble,
        languageCode: languageCode,
        popupTopInset: popupTopInset,
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(12, topGap, 12, 0),
      child: Column(
        crossAxisAlignment:
            isOut ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          bubble,
          if (isLastInGroup) ...[
            const SizedBox(height: 4),
            _Meta(message: message),
          ],
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.showTranslation,
    required this.maxWidth,
    required this.languageCode,
    required this.popupTopInset,
  });

  final Message message;
  final bool showTranslation;
  final double maxWidth;
  final String languageCode;
  final double popupTopInset;

  @override
  Widget build(BuildContext context) {
    final isOut = message.isOutgoing;

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

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        decoration: BoxDecoration(
          color: isOut ? BlabColors.brand : BlabColors.phoneSurface,
          borderRadius: radius,
          border: isOut ? null : Border.all(color: Colors.grey.shade200),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.replyTo != null) ...[
              _QuotedReply(replyTo: message.replyTo!, parentIsOutgoing: isOut),
              const SizedBox(height: 6),
            ],
            // Learning language always shown as main bubble text. For
            // outgoing messages we display the Tamil translation as main
            // and Nastia's typed English as the subtitle, so both sides
            // of the bubble mirror the incoming layout. PRD design
            // principles: "Partner's language always shown first; English
            // always second." For live-typed sends without a translation
            // yet, fall back to showing just the original.
            MessageText(
              text: isOut && message.translation.isNotEmpty
                  ? message.translation
                  : message.originalText,
              tokens: message.tokens,
              languageCode: languageCode,
              popupTopInset: popupTopInset,
              style: TextStyle(
                fontSize: 16,
                height: 1.7,
                color: isOut ? Colors.white : BlabColors.textPrimary,
              ),
            ),
            if (showTranslation &&
                message.translation.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  height: 1,
                  color: isOut
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.grey.shade200,
                ),
              ),
              Text(
                isOut ? message.originalText : message.translation,
                style: TextStyle(
                  fontSize: 14,
                  color: isOut
                      ? Colors.white.withValues(alpha: 0.85)
                      : BlabColors.textMuted,
                  fontStyle: FontStyle.italic,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.message});
  final Message message;

  @override
  Widget build(BuildContext context) {
    final timeLabel = _formatTime(message.sentAt);
    final children = <Widget>[
      Text(
        timeLabel,
        style: const TextStyle(
          fontSize: 11,
          color: BlabColors.textMuted,
        ),
      ),
    ];
    if (message.isEdited) {
      children.add(const SizedBox(width: 4));
      children.add(const Text(
        '· edited',
        style: TextStyle(
          fontSize: 10,
          color: BlabColors.textMuted,
        ),
      ));
    }
    if (message.isOutgoing) {
      children.add(const SizedBox(width: 4));
      children.add(_StatusIcon(status: message.status));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  static String _formatTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    // Semantics labels paired with the icon — read receipts and online
    // indicators must not be color-only. PRD US-033.
    switch (status) {
      case MessageStatus.pending:
        return Semantics(
          label: 'Sending',
          child: const Icon(Icons.access_time,
              size: 14, color: BlabColors.textMuted),
        );
      case MessageStatus.delivered:
        return Semantics(
          label: 'Delivered',
          child: Icon(Icons.done_all, size: 14, color: Colors.grey.shade500),
        );
      case MessageStatus.read:
        return Semantics(
          label: 'Read',
          child: const Icon(Icons.done_all,
              size: 14, color: BlabColors.brand),
        );
      case MessageStatus.failed:
        return Semantics(
          label: 'Failed to send. Tap to retry.',
          child: const Icon(Icons.error_outline,
              size: 14, color: Color(0xFFEF4444)),
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
    required this.onSend,
  });

  final TextEditingController controller;
  final bool hasText;
  final String hintText;
  final int textLength;
  final int maxLength;
  final int counterShowAt;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final overLimit = textLength > maxLength;
    final canSend = hasText && !overLimit;
    final showCounter = textLength >= counterShowAt;
    final atLimit = textLength >= maxLength;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
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
                  IconButton(
                    tooltip: 'Attach',
                    icon:
                        Icon(Icons.add, color: Colors.grey.shade500, size: 26),
                    onPressed: null,
                    splashRadius: 22,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Semantics(
                      label: 'Message',
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 5,
                        maxLength: maxLength,
                        // Hide the default counter — we render our own
                        // (right-aligned, only at threshold). PRD US-036.
                        buildCounter: (
                          context, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) =>
                            null,
                        textCapitalization: TextCapitalization.sentences,
                        style: const TextStyle(
                          fontSize: 15,
                          color: BlabColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: hintText,
                          hintStyle: const TextStyle(
                            color: BlabColors.textMuted,
                            fontSize: 15,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
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
                            message: 'Send',
                            child: const Icon(
                              Icons.arrow_upward,
                              color: Colors.white,
                              size: 22,
                              semanticLabel: 'Send',
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
  });

  final Message replyTo;
  final bool parentIsOutgoing;

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

    final author = replyTo.isOutgoing ? 'You' : 'Aswin';

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(color: tintBg),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 4, color: barColor),
              const SizedBox(width: 8),
              Flexible(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
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
                        replyTo.originalText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: previewColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
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
    final whose = message.isOutgoing ? 'yourself' : partnerName;
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
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Replying to $whose',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: BlabColors.brand,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message.originalText,
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
                child: Icon(
                  Icons.close,
                  size: 20,
                  color: BlabColors.textMuted,
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
class _FirstMessageEmptyState extends StatelessWidget {
  const _FirstMessageEmptyState({required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ExchangeCard(
          topFlag: chat.learningLanguage.flag,
          topLabel: 'You learn ${chat.learningLanguage.name}',
          bottomFlag: chat.partnerLearningLanguage.flag,
          bottomLabel:
              'Help ${chat.partnerName} learn ${chat.partnerLearningLanguage.name}',
        ),
      ),
    );
  }
}

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
                    'Editing message',
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
                child: Icon(
                  Icons.close,
                  size: 20,
                  color: BlabColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

