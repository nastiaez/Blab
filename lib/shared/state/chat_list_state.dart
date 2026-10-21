import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/languages.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../services/local_chat_history_cache.dart';
import '../services/stream_backed_chat_service.dart';
import 'auth_state.dart';
import '../../features/chat/state/pending_sends_state.dart';
import '../../features/chat/state/message_translations_state.dart';
import '../../features/chat/state/unread_chat_state.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  ref.watch(currentUserIdProvider);
  final service = createChatService(ref.watch(supabaseClientProvider));
  if (service is StreamBackedChatService) {
    ref.onDispose(() => unawaited(service.dispose()));
  }
  return service;
});

Chat _rowToChat(Map<String, dynamic> r) {
  BlabLanguage lang(String code) => kBlabLanguages.firstWhere(
    (l) => l.code == code,
    orElse: () => kBlabLanguages.firstWhere((l) => l.code == 'en'),
  );
  final myLearn = lang((r['my_learning'] as String?) ?? 'en');
  final partnerLearn = lang((r['partner_learning'] as String?) ?? 'en');
  final raw = (r['partner_name'] as String?) ?? '';
  final name = raw.trim().isEmpty ? '?' : raw.trim();
  return Chat(
    id: r['chat_id'] as String,
    partnerId: r['partner_id'] as String?,
    leftAt: DateTime.tryParse(r['left_at'] as String? ?? ''),
    historyClearedAt: DateTime.tryParse(
      r['history_cleared_at'] as String? ?? '',
    ),
    partnerName: name,
    partnerInitial: name == '?' ? '?' : name[0].toUpperCase(),
    learningLanguage: myLearn,
    mode: chatModeFromDb(r['my_mode'] as String?),
    partnerNativeLanguage: myLearn,
    partnerLearningLanguage: partnerLearn,
    translationCutoffAt: r['translation_cutoff_at'] == null
        ? null
        : DateTime.parse(r['translation_cutoff_at'] as String).toLocal(),
    lastMessage: r['needs_practice_language_selection'] == true
        ? (r['last_body'] as String?) ?? ''
        : (r['last_practice_body'] as String?) ??
              (r['last_body'] as String?) ??
              '',
    lastMessageTranslation: (r['last_practice_body'] as String?) ?? '',
    lastMessageId: r['last_message_id'] as String?,
    timestamp: r['last_at'] != null
        ? DateTime.parse(r['last_at'] as String).toLocal()
        : DateTime.now(),
    unreadCount: (r['unread_count'] as int?) ?? 0,
    needsPracticeLanguageSelection:
        r['needs_practice_language_selection'] as bool? ?? false,
    kind: r['chat_kind'] == 'group' ? ChatKind.group : ChatKind.direct,
    memberCount: (r['member_count'] as int?) ?? 2,
    ownerId: r['owner_id'] as String?,
    aiStartedAt: DateTime.tryParse(r['ai_started_at'] as String? ?? ''),
  );
}

class ChatListNotifier extends AsyncNotifier<List<Chat>> {
  StreamSubscription<dynamic>? _membershipsSub;
  StreamSubscription<void>? _messagesSub;
  StreamSubscription<void>? _translationsSub;
  Timer? _refreshDebounce;
  Future<void>? _refreshInFlight;
  int _selectionRevision = 0;

  @override
  Future<List<Chat>> build() async {
    // Rebuild on auth changes so sign-out/sign-in returns fresh chats
    // scoped to the new user.
    ref.watch(authSessionProvider);
    final svc = ref.watch(chatServiceProvider);
    final localCache = ref.watch(localChatHistoryCacheProvider);

    _membershipsSub?.cancel();
    _messagesSub?.cancel();
    _translationsSub?.cancel();
    _refreshDebounce?.cancel();
    // Subscribe to my chat_members changes so the list refreshes when a new
    // chat is created or a member leaves. Errors (e.g. transient network
    // drops) are swallowed — the next successful emission catches up.
    _membershipsSub = svc.watchMyMemberships().listen(
      (_) => _scheduleRefresh(),
      onError: (Object _) {},
    );
    _messagesSub = svc.watchChatListMessageChanges().listen(
      (_) => _scheduleRefresh(),
      onError: (Object _) {},
    );
    _translationsSub = svc.watchChatListTranslationChanges().listen(
      (_) => _scheduleRefresh(),
      onError: (Object _) {},
    );
    ref.onDispose(() {
      _refreshDebounce?.cancel();
      _membershipsSub?.cancel();
      _messagesSub?.cancel();
      _translationsSub?.cancel();
    });

    final cached = await localCache?.loadChats() ?? const <Chat>[];
    if (cached.isNotEmpty) {
      // Paint the account-scoped snapshot first. A reachable server refreshes
      // it immediately after build; an unreachable one must not hold the
      // whole chat list behind the transport timeout (US-031 / FR-41).
      Future<void>.microtask(() async {
        if (!ref.mounted) return;
        await _refresh();
      });
      return cached;
    }

    try {
      final rows = await svc.fetchChatList();
      final chats = rows.map(_rowToChat).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      unawaited(localCache?.saveChats(chats));
      return chats;
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Chat list fetch failed: type=${error.runtimeType}, error=$error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      rethrow;
    }
  }

  /// Force a refetch. Callers (e.g., the chat screen, after sending or
  /// receiving a message) can poke this to update last-message + unread
  /// counts without waiting for membership events.
  Future<void> refresh() {
    final active = _refreshInFlight;
    if (active != null) return active;
    final pending = _refresh();
    _refreshInFlight = pending.whenComplete(() => _refreshInFlight = null);
    return _refreshInFlight!;
  }

  /// US-027: an acknowledged choice survives an offline/stale list refresh.
  void confirmPracticeLanguageSelection(String chatId, BlabLanguage language) {
    _selectionRevision++;
    final chats = state.value;
    if (chats == null) return;
    final updated = chats.map((chat) {
      if (chat.id != chatId || !chat.needsPracticeLanguageSelection) {
        return chat;
      }
      return Chat(
        id: chat.id,
        leftAt: chat.leftAt,
        historyClearedAt: chat.historyClearedAt,
        partnerId: chat.partnerId,
        partnerName: chat.partnerName,
        partnerInitial: chat.partnerInitial,
        learningLanguage: language,
        mode: chat.mode,
        partnerNativeLanguage: chat.partnerNativeLanguage,
        partnerLearningLanguage: chat.partnerLearningLanguage,
        lastMessage: chat.lastMessage,
        lastMessageTranslation: chat.lastMessageTranslation,
        lastMessageId: chat.lastMessageId,
        timestamp: chat.timestamp,
        unreadCount: chat.unreadCount,
        isNewInvite: chat.isNewInvite,
        startedAt: chat.startedAt,
        translationCutoffAt: chat.translationCutoffAt,
        kind: chat.kind,
        memberCount: chat.memberCount,
        ownerId: chat.ownerId,
        aiStartedAt: chat.aiStartedAt,
      );
    }).toList();
    state = AsyncValue.data(updated);
    unawaited(ref.read(localChatHistoryCacheProvider)?.saveChats(updated));
  }

  Future<void> deleteChat(String chatId) async {
    await ref.read(chatServiceProvider).deleteChat(chatId);
    _selectionRevision++;
    final chats = state.value;
    if (chats != null) {
      final updated = chats.where((chat) => chat.id != chatId).toList();
      state = AsyncValue.data(updated);
      await ref.read(localChatHistoryCacheProvider)?.saveChats(updated);
    }
    await ref.read(localChatHistoryCacheProvider)?.clearChatHistory(chatId);
    await refresh();
  }

  Future<void> leaveChat(String chatId) async {
    await ref.read(chatServiceProvider).leaveChat(chatId);
    _selectionRevision++;
    final chats = state.value;
    if (chats != null) {
      final updated = chats
          .map(
            (chat) =>
                chat.id == chatId ? chat.withLeftAt(DateTime.now()) : chat,
          )
          .toList();
      state = AsyncValue.data(updated);
      await ref.read(localChatHistoryCacheProvider)?.saveChats(updated);
    }
    await refresh();
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 75), refresh);
  }

  Future<void> _refresh() async {
    final svc = ref.read(chatServiceProvider);
    final localCache = ref.read(localChatHistoryCacheProvider);
    try {
      while (ref.mounted) {
        final selectionRevision = _selectionRevision;
        final rows = await svc.fetchChatList();
        if (!ref.mounted) return;
        // US-027: never replace an acknowledged choice with a pre-save snapshot.
        if (selectionRevision != _selectionRevision) continue;
        final chats = rows.map(_rowToChat).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final changedGroups = <String>[];
        for (final old in state.asData?.value ?? const <Chat>[]) {
          if (!old.isGroup) continue;
          final current = chats
              .where((entry) => entry.id == old.id)
              .firstOrNull;
          if (current == null || current.aiStartedAt != old.aiStartedAt) {
            if (ref.exists(pendingSendsProvider(old.id))) {
              await ref
                  .read(pendingSendsProvider(old.id).notifier)
                  .discardForMembershipChange();
            }
            await localCache?.clearChatHistory(old.id);
            if (!ref.mounted) return;
            changedGroups.add(old.id);
          }
        }
        state = AsyncValue.data(chats);
        for (final id in changedGroups) {
          ref.invalidate(messageTranslationsProvider(id));
          ref.invalidate(chatLanguageTimelineProvider(id));
          ref.invalidate(chatUnreadMessageIdsProvider(id));
        }
        unawaited(localCache?.saveChats(chats));
        return;
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Chat list refresh failed: type=${e.runtimeType}, error=$e');
        debugPrintStack(stackTrace: st);
      }
      // If we already have data, keep showing it on transient errors
      // (e.g. offline). Only surface the error when we have nothing yet.
      if (state.hasValue) return;
      final cached = await localCache?.loadChats() ?? const <Chat>[];
      if (cached.isNotEmpty) {
        state = AsyncValue.data(cached);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }
}

final chatListProvider = AsyncNotifierProvider<ChatListNotifier, List<Chat>>(
  ChatListNotifier.new,
);

/// Realtime set of user ids the current user has blocked. Empty when
/// signed-out or on error. Step 3.6a.
final blockedUserIdsProvider = StreamProvider<Set<String>>((ref) {
  ref.watch(authSessionProvider);
  final svc = ref.watch(chatServiceProvider);
  try {
    return svc.watchBlockedIds();
  } catch (_) {
    return Stream.value(const <String>{});
  }
});

/// Drop chats whose partner the user has blocked from surfaces that can send
/// immediately, such as the Android share-photo picker. The primary Chats
/// screen intentionally renders [chatListProvider] directly so a blocked
/// conversation remains available as its recovery surface.
List<Chat> filterShareableChats(List<Chat> chats, Set<String> blocked) => chats
    .where(
      (c) =>
          !c.isLeft && (c.partnerId == null || !blocked.contains(c.partnerId)),
    )
    .toList();

/// Chats that are safe to present as immediate send targets.
final shareableChatsProvider = Provider<AsyncValue<List<Chat>>>((ref) {
  final chats = ref.watch(chatListProvider);
  final blocked = ref.watch(blockedUserIdsProvider).value ?? const <String>{};
  return chats.whenData((list) => filterShareableChats(list, blocked));
});
