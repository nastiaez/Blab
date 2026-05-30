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
    partnerName: name,
    partnerInitial: name == '?' ? '?' : name[0].toUpperCase(),
    learningLanguage: myLearn,
    partnerNativeLanguage: myLearn,
    partnerLearningLanguage: partnerLearn,
    lastMessage: (r['last_body'] as String?) ?? '',
    lastMessageTranslation: '',
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
    final svc = ref.watch(chatServiceProvider);

    _membershipsSub?.cancel();
    _membershipsSub = svc.watchMyMemberships().listen((_) => refresh());
    ref.onDispose(() => _membershipsSub?.cancel());

    final rows = await svc.fetchChatList();
    return rows.map(_rowToChat).toList();
  }

  /// Force a refetch. Callers (e.g., the chat screen, after sending or
  /// receiving a message) can poke this to update last-message + unread
  /// counts without waiting for membership events.
  Future<void> refresh() async {
    final svc = ref.read(chatServiceProvider);
    state = const AsyncValue.loading();
    try {
      final rows = await svc.fetchChatList();
      state = AsyncValue.data(rows.map(_rowToChat).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final chatListProvider =
    AsyncNotifierProvider<ChatListNotifier, List<Chat>>(ChatListNotifier.new);
