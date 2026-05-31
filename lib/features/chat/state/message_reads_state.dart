import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/state/auth_state.dart';
import '../../../shared/state/chat_list_state.dart';

typedef MarkReadFn = Future<void> Function(List<String> ids);

/// Per-chat function pointer for marking ids read. Overridable in tests.
final markReadFnProvider = Provider.family<MarkReadFn, String>((ref, chatId) {
  final svc = ref.watch(chatServiceProvider);
  return (ids) => svc.markRead(chatId: chatId, messageIds: ids);
});

/// Collects ids of incoming messages that have just scrolled into view and
/// flushes them to `ChatService.markRead` after a 250 ms debounce. Idempotent
/// — duplicate `reportVisible(id)` calls inside the window are coalesced into
/// a single upsert. Step 2.2 Task 10 / PRD US-016.
class MessageReadsNotifier extends Notifier<Set<String>> {
  MessageReadsNotifier(this.chatId);
  final String chatId;
  Timer? _flush;

  @override
  Set<String> build() {
    ref.onDispose(() => _flush?.cancel());
    return <String>{};
  }

  void reportVisible(String id) {
    if (state.contains(id)) return;
    state = {...state, id};
    _flush?.cancel();
    _flush = Timer(const Duration(milliseconds: 250), _flushNow);
  }

  Future<void> _flushNow() async {
    final ids = state.toList();
    if (ids.isEmpty) return;
    state = <String>{};
    final fn = ref.read(markReadFnProvider(chatId));
    try {
      await fn(ids);
    } catch (_) {
      // Best-effort — silently drop. The next visibility tick will retry.
    }
  }
}

final messageReadsProvider =
    NotifierProvider.family<MessageReadsNotifier, Set<String>, String>(
  MessageReadsNotifier.new,
);

/// Set of message ids in this chat that the OTHER user has read. Outgoing
/// bubbles render as `read` when their id is in this set.
final readsForChatProvider =
    StreamProvider.family<Set<String>, String>((ref, chatId) {
  // Re-open the realtime subscription when the signed-in user changes,
  // otherwise the channel keeps using the previous account's auth context
  // and outgoing bubbles stay stuck on the gray double-tick.
  ref.watch(authSessionProvider);
  final svc = ref.watch(chatServiceProvider);
  return svc.watchReads(chatId).map((rows) {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    return rows
        .where((r) => r['user_id'] != uid)
        .map((r) => r['message_id'] as String)
        .toSet();
  });
});
