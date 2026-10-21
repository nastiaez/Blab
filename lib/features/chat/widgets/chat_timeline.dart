part of '../chat_screen.dart';

class ChatHistoryErrorState extends StatelessWidget {
  const ChatHistoryErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.couldNotLoadMessages,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: BlabColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              key: const ValueKey('chat-history-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatTimeline extends ConsumerWidget {
  const ChatTimeline({
    super.key,
    this.highlightedMessageId,
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
    required this.onJumpToMessage,
    required this.onFailedTap,
    required this.onFailedRetry,
    required this.onReact,
    this.onDoubleTapHeart,
    required this.selectedMessageId,
    required this.showSelectedOriginal,
    required this.selectedBubbleKey,
    this.emptyState,
  });

  final String? highlightedMessageId;
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
  final void Function(Message) onJumpToMessage;
  final void Function(Message) onFailedTap;
  final void Function(Message) onFailedRetry;
  final void Function(Message) onReact;
  final void Function(Message)? onDoubleTapHeart;
  final String? selectedMessageId;
  final bool showSelectedOriginal;
  final GlobalKey selectedBubbleKey;
  final Widget? emptyState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (messages.isEmpty) {
      return emptyState ?? const SizedBox.expand();
    }

    final group =
        ref
            .watch(chatListProvider)
            .asData
            ?.value
            .any((chat) => chat.id == chatId && chat.isGroup) ??
        false;
    final languageTimeline = parseChatLanguageTimeline(languageTimelineRows);
    ChatLanguageEra eraForMessage(Message message) => languageEraForMessage(
      sentAt: message.sentAt,
      timeline: languageTimeline,
      fallbackLanguageCode: languageCode,
    );

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
          prev.type == MessageType.groupJoined ||
          prev.isOutgoing != m.isOutgoing ||
          prev.senderId != m.senderId ||
          startsNewDate ||
          m.sentAt.difference(prev.sentAt).inMinutes.abs() > 2;
      final messageTopGap = isFirstInGroup ? 10.0 : 2.0;

      if (startsNewDate) {
        items.add(_DateDividerItem(m.sentAt));
      }
      if (m.type == MessageType.groupJoined) {
        items.add(
          _GroupJoinedItem(
            m.senderName,
            afterMessage: prev != null && prev.type != MessageType.groupJoined,
          ),
        );
        continue;
      }
      ({DateTime? when, String? language})? visibleChange;
      while (languageChangeIndex < languageChanges.length &&
          !languageChanges[languageChangeIndex].when!.isAfter(m.sentAt)) {
        visibleChange = languageChanges[languageChangeIndex++];
      }
      if (visibleChange != null) {
        items.add(
          _LanguageTimelineItem(
            languageCode: visibleChange.language!,
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
          next.type == MessageType.groupJoined ||
          next.isOutgoing != m.isOutgoing ||
          next.senderId != m.senderId ||
          !_isSameDay(next.sentAt, m.sentAt) ||
          next.sentAt.difference(m.sentAt).inMinutes.abs() > 2;

      items.add(
        _MessageItem(
          message: m,
          isFirstInGroup: isFirstInGroup,
          isLastInGroup: isLastInGroup,
          leadingGap:
              group &&
                  prev?.type == MessageType.groupJoined &&
                  i >= 2 &&
                  messages[i - 2].type != MessageType.groupJoined
              ? 0
              : null,
        ),
      );
    }
    if (languageChangeIndex < languageChanges.length) {
      final change = languageChanges.last;
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
        if (item is _GroupJoinedItem) {
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 24,
              vertical: group ? (item.afterMessage ? 12 : 5) : 10,
            ),
            child: Center(
              child: Text(
                item.name == null
                    ? context.l10n.someoneJoined
                    : context.l10n.groupMemberJoined(item.name!),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: group ? const Color(0xFF6F5C50) : BlabColors.warmMuted,
                  height: group ? 16 / 12 : null,
                ),
              ),
            ),
          );
        }
        if (item is _DateDividerItem) {
          return ChatDateDivider(when: item.when, groupConversation: group);
        }
        if (item is _UnreadDividerItem) {
          return ChatUnreadDivider(key: unreadDividerKey, count: item.count);
        }
        if (item is _LanguageTimelineItem) {
          return ChatLanguageMarker(
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
            child: ChatMessageRow(
              highlighted: highlightedMessageId == item.message.id,
              leadingGap: item.leadingGap,
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
              isSelected: selectedMessageId == item.message.id,
              showOriginal:
                  selectedMessageId == item.message.id && showSelectedOriginal,
              selectedBubbleKey: selectedMessageId == item.message.id
                  ? selectedBubbleKey
                  : null,
              onLongPress: (rect, position) =>
                  onLongPress(item.message, rect, position),
              onReply: () => onReply(item.message),
              onJumpToMessage: onJumpToMessage,
              onFailedTap: () => onFailedTap(item.message),
              onFailedRetry: () => onFailedRetry(item.message),
              onReact: () => onReact(item.message),
              onDoubleTapHeart: onDoubleTapHeart == null
                  ? null
                  : () => onDoubleTapHeart!(item.message),
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

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

sealed class _ListItem {
  const _ListItem();
}

class _GroupJoinedItem extends _ListItem {
  const _GroupJoinedItem(this.name, {this.afterMessage = false});
  final bool afterMessage;
  final String? name;
}

class _DateDividerItem extends _ListItem {
  const _DateDividerItem(this.when);
  final DateTime when;
}

class _UnreadDividerItem extends _ListItem {
  const _UnreadDividerItem(this.count);
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

class ChatLanguageMarker extends StatelessWidget {
  const ChatLanguageMarker({
    super.key,
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
          context.l10n.learningTimelineMarker(languageCode),
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
    this.leadingGap,
  });
  final double? leadingGap;
  final Message message;
  final bool isFirstInGroup;
  final bool isLastInGroup;
}

class ChatDateDivider extends StatelessWidget {
  const ChatDateDivider({
    super.key,
    required this.when,
    this.groupConversation = false,
  });
  final bool groupConversation;
  final DateTime when;

  @override
  Widget build(BuildContext context) {
    final label = _formatDay(context, when);
    return Padding(
      padding: groupConversation
          ? const EdgeInsets.only(bottom: 16)
          : const EdgeInsets.only(top: 18, bottom: 10),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            height: groupConversation ? 16 / 12 : null,
            color: BlabColors.textMuted,
            fontWeight: groupConversation ? FontWeight.w400 : FontWeight.w500,
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

class ChatUnreadDivider extends StatelessWidget {
  const ChatUnreadDivider({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = context.l10n.newMessages(count);
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

// ─────────────────────────── message row ─────────────────────────────────────
