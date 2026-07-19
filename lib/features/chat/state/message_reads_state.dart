import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/state/auth_state.dart';
import '../../../shared/state/chat_list_state.dart';
import '../../../shared/state/privacy_settings.dart';

typedef MarkReadFn = Future<void> Function(List<String> ids);
typedef WatchReadsFn = Stream<List<Map<String, dynamic>>> Function();

/// Per-chat function pointer for marking ids read. Overridable in tests.
final markReadFnProvider = Provider.family<MarkReadFn, String>((ref, chatId) {
  final svc = ref.watch(chatServiceProvider);
  return (ids) => svc.markRead(chatId: chatId, messageIds: ids);
});

/// Per-chat read stream pointer for transport-boundary tests.
final watchReadsFnProvider = Provider.family<WatchReadsFn, String>((
  ref,
  chatId,
) {
  final svc = ref.watch(chatServiceProvider);
  return () => svc.watchReads(chatId);
});

final readReceiptUserIdProvider = Provider<String?>((ref) {
  ref.watch(authSessionProvider);
  try {
    return Supabase.instance.client.auth.currentUser?.id;
  } catch (_) {
    return null;
  }
});

/// Collects ids of incoming messages that have just scrolled into view and
/// flushes them to `ChatService.markRead` after a 250 ms debounce. Idempotent
/// — duplicate `reportVisible(id)` calls inside the window are coalesced into
/// a single upsert. Step 2.2 Task 10 / PRD US-016.
class MessageReadsNotifier extends Notifier<Set<String>> {
  MessageReadsNotifier(this.chatId);
  final String chatId;
  final Set<String> _pending = <String>{};
  Timer? _flush;

  @override
  Set<String> build() {
    final privacy = ref.watch(readReceiptsTransportStateProvider);
    if (privacy.isLoaded && !privacy.enabled) {
      _flush?.cancel();
      _flush = null;
      _pending.clear();
    } else if (privacy.canTransmit && _pending.isNotEmpty) {
      _scheduleFlush();
    }
    ref.onDispose(() => _flush?.cancel());
    return Set<String>.unmodifiable(_pending);
  }

  void reportVisible(String id) {
    final privacy = ref.read(readReceiptsTransportStateProvider);
    if (privacy.isLoaded && !privacy.enabled) return;
    if (!_pending.add(id)) return;
    state = Set<String>.unmodifiable(_pending);
    if (!privacy.canTransmit) return;
    _scheduleFlush();
  }

  void _scheduleFlush() {
    _flush?.cancel();
    _flush = Timer(const Duration(milliseconds: 250), _flushNow);
  }

  Future<void> _flushNow() async {
    final privacy = ref.read(readReceiptsTransportStateProvider);
    if (!privacy.isLoaded) return;
    if (!privacy.enabled) {
      _pending.clear();
      state = <String>{};
      return;
    }
    final ids = _pending.toList();
    if (ids.isEmpty) return;
    _pending.clear();
    state = <String>{};
    final fn = ref.read(markReadFnProvider(chatId));
    try {
      await fn(ids);
      // Nudge the chat list so the unread badge updates immediately
      // rather than waiting for the next tile rebuild. Best-effort —
      // a missing chat-list provider (e.g. headless tests without
      // Supabase) must not bubble out of this fire-and-forget timer.
      try {
        await ref.read(chatListProvider.notifier).refresh();
      } catch (_) {}
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
final readsForChatProvider = StreamProvider.family<Set<String>, String>((
  ref,
  chatId,
) {
  if (!ref.watch(readReceiptsEnabledProvider)) {
    return Stream.value(const <String>{});
  }
  // Re-open the realtime subscription when the signed-in user changes,
  // otherwise the channel keeps using the previous account's auth context
  // and outgoing bubbles stay stuck on the gray double-tick.
  ref.watch(authSessionProvider);
  final watchReads = ref.watch(watchReadsFnProvider(chatId));
  final uid = ref.watch(readReceiptUserIdProvider);
  return watchReads().map((rows) {
    return rows
        .where((r) => r['user_id'] != uid)
        .map((r) => r['message_id'] as String)
        .toSet();
  });
});
