import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/languages.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
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
    partnerNativeLanguage: myLearn,
    partnerLearningLanguage: partnerLearn,
    lastMessage: (r['last_body'] as String?) ?? '',
    lastMessageTranslation: '',
    lastMessageId: r['last_message_id'] as String?,
    timestamp: r['last_at'] != null
        ? DateTime.parse(r['last_at'] as String).toLocal()
        : DateTime.now(),
    unreadCount: (r['unread_count'] as int?) ?? 0,
  );
}

class ChatListNotifier extends AsyncNotifier<List<Chat>> {
  StreamSubscription<dynamic>? _membershipsSub;

  @override
  Future<List<Chat>> build() async {
    // Rebuild on auth changes so sign-out/sign-in returns fresh chats
    // scoped to the new user.
    ref.watch(authSessionProvider);
    final svc = ref.watch(chatServiceProvider);

    _membershipsSub?.cancel();
    // Subscribe to my chat_members changes so the list refreshes when a new
    // chat is created or a member leaves. Errors (e.g. transient network
    // drops) are swallowed — the next successful emission catches up.
    _membershipsSub = svc.watchMyMemberships().listen(
      (_) => refresh(),
      onError: (Object _) {},
    );
    ref.onDispose(() => _membershipsSub?.cancel());

    final rows = await svc.fetchChatList();
    return rows.map(_rowToChat).toList();
  }

  /// Force a refetch. Callers (e.g., the chat screen, after sending or
  /// receiving a message) can poke this to update last-message + unread
  /// counts without waiting for membership events.
  Future<void> refresh() async {
    final svc = ref.read(chatServiceProvider);
    try {
      final rows = await svc.fetchChatList();
      state = AsyncValue.data(rows.map(_rowToChat).toList());
    } catch (e, st) {
      // If we already have data, keep showing it on transient errors
      // (e.g. offline). Only surface the error when we have nothing yet.
      if (state.hasValue) return;
      state = AsyncValue.error(e, st);
    }
  }
}

final chatListProvider =
    AsyncNotifierProvider<ChatListNotifier, List<Chat>>(ChatListNotifier.new);

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
  final blocked =
      ref.watch(blockedUserIdsProvider).value ?? const <String>{};
  return chats.whenData((list) => filterBlockedChats(list, blocked));
});
