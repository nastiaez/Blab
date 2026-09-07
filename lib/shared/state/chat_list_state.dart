import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/languages.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../services/local_chat_history_cache.dart';
import '../services/message_translator.dart';
import 'auth_state.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(ref.watch(supabaseClientProvider));
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
    partnerName: name,
    partnerInitial: name == '?' ? '?' : name[0].toUpperCase(),
    learningLanguage: myLearn,
    mode: chatModeFromDb(r['my_mode'] as String?),
    partnerNativeLanguage: myLearn,
    partnerLearningLanguage: partnerLearn,
    translationCutoffAt: r['translation_cutoff_at'] == null
        ? null
        : DateTime.parse(r['translation_cutoff_at'] as String).toLocal(),
    lastMessage: (r['last_body'] as String?) ?? '',
    lastMessageTranslation: '',
    lastMessageId: r['last_message_id'] as String?,
    timestamp: r['last_at'] != null
        ? DateTime.parse(r['last_at'] as String).toLocal()
        : DateTime.now(),
    unreadCount: (r['unread_count'] as int?) ?? 0,
    needsPracticeLanguageSelection:
        r['needs_practice_language_selection'] as bool? ?? false,
  );
}

class ChatListNotifier extends AsyncNotifier<List<Chat>> {
  StreamSubscription<dynamic>? _membershipsSub;
  StreamSubscription<void>? _messagesSub;
  StreamSubscription<void>? _translationsSub;
  Timer? _refreshDebounce;
  Future<void>? _refreshInFlight;

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
      final chats = rows.map(_rowToChat).toList();
      unawaited(localCache?.saveChats(chats));
      unawaited(_prepareRecentMessages(chats));
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

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 75), refresh);
  }

  Future<void> _refresh() async {
    final svc = ref.read(chatServiceProvider);
    final localCache = ref.read(localChatHistoryCacheProvider);
    try {
      final rows = await svc.fetchChatList();
      final chats = rows.map(_rowToChat).toList();
      state = AsyncValue.data(chats);
      unawaited(localCache?.saveChats(chats));
      unawaited(_prepareRecentMessages(chats));
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

  Future<void> _prepareRecentMessages(List<Chat> chats) async {
    final translator = ref.read(messageTranslatorProvider);
    final service = ref.read(chatServiceProvider);
    // Three in-flight provider calls match the chat-open background budget
    // while keeping delivery preparation bounded on a small device.
    const concurrency = 3;
    final queue = <Future<void> Function()>[];
    for (final chat in chats) {
      try {
        final ids = await service.fetchPreparationMessageIds(chat.id);
        for (final id in ids) {
          queue.add(() async {
            try {
              await translator.translate(messageId: id);
            } catch (_) {
              // A later chat open retries the durable job; preparation must
              // never make the chat list itself fail.
            }
          });
        }
      } catch (_) {
        // Offline list cache remains usable; reconnect will retry.
      }
    }
    var cursor = 0;
    Future<void> worker() async {
      while (cursor < queue.length) {
        final task = queue[cursor++];
        await task();
      }
    }

    await Future.wait(
      List<Future<void>>.generate(
        queue.length < concurrency ? queue.length : concurrency,
        (_) => worker(),
      ),
    );
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

/// Drop chats whose partner the user has blocked. Pure so it can be unit
/// tested without provider/stream timing. Chats with no partner id (mocks)
/// always pass. Step 3.6a.
List<Chat> filterBlockedChats(List<Chat> chats, Set<String> blocked) => chats
    .where((c) => c.partnerId == null || !blocked.contains(c.partnerId))
    .toList();

/// The chat list with blocked partners filtered out. Screens render this
/// instead of [chatListProvider] so blocking a person removes their chat
/// from the list immediately (and it returns on unblock). Step 3.6a.
final visibleChatsProvider = Provider<AsyncValue<List<Chat>>>((ref) {
  final chats = ref.watch(chatListProvider);
  final blocked = ref.watch(blockedUserIdsProvider).value ?? const <String>{};
  return chats.whenData((list) => filterBlockedChats(list, blocked));
});
