import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/state/auth_state.dart';
import '../../../shared/state/chat_list_state.dart';
import '../../../shared/state/privacy_settings.dart';
import '../../../shared/services/local_chat_signals_cache.dart';
import 'unread_chat_state.dart';

typedef MarkReadFn =
    Future<void> Function(List<String> ids, {required bool receiptVisible});
typedef WatchReadsFn = Stream<List<Map<String, dynamic>>> Function();

typedef ClearReadNotificationsFn =
    Future<void> Function(String userId, String chatId, List<String> ids);
final clearReadNotificationsProvider = Provider<ClearReadNotificationsFn>((
  ref,
) {
  return (userId, chatId, ids) async {
    try {
      await const MethodChannel('blab/notifications').invokeMethod<void>(
        'clearReadNotifications',
        {'userId': userId, 'chatId': chatId, 'messageIds': ids},
      );
    } on MissingPluginException {
      // Non-Android preview.
    } on PlatformException {
      // Notification clearing must not block reading.
    }
  };
});

/// Per-chat function pointer for marking ids read. Overridable in tests.
final markReadFnProvider = Provider.family<MarkReadFn, String>((ref, chatId) {
  final svc = ref.watch(chatServiceProvider);
  return (ids, {required receiptVisible}) => svc.markRead(
    chatId: chatId,
    messageIds: ids,
    receiptVisible: receiptVisible,
  );
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
  String? _activeUserId;
  bool _identityInitialized = false;

  @override
  Set<String> build() {
    final userId = ref.watch(currentUserIdProvider);
    if (_identityInitialized && userId != _activeUserId) {
      _flush?.cancel();
      _pending.clear();
    }
    _activeUserId = userId;
    _identityInitialized = true;
    final privacy = ref.watch(readReceiptsTransportStateProvider);
    if (privacy.isLoaded && !privacy.enabled) {
      _flush?.cancel();
      _pending.clear();
    } else if (privacy.isLoaded && _pending.isNotEmpty) {
      _scheduleFlush();
    }
    ref.onDispose(() => _flush?.cancel());
    return Set<String>.unmodifiable(_pending);
  }

  void reportVisible(String id) {
    final userId = ref.read(currentUserIdProvider);
    if (userId != null) {
      unawaited(ref.read(clearReadNotificationsProvider)(userId, chatId, [id]));
    }
    final privacy = ref.read(readReceiptsTransportStateProvider);
    if (privacy.isLoaded && !privacy.enabled) return;
    if (!_pending.add(id)) return;
    state = Set<String>.unmodifiable(_pending);
    if (!privacy.isLoaded) return;
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
      await fn(ids, receiptVisible: true);
      ref.invalidate(chatUnreadMessageIdsProvider(chatId));
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
) async* {
  if (!ref.watch(readReceiptsEnabledProvider)) {
    yield const <String>{};
    return;
  }
  // Re-open the realtime subscription when the signed-in user changes,
  // otherwise the channel keeps using the previous account's auth context
  // and outgoing bubbles stay stuck on the gray double-tick.
  ref.watch(authSessionProvider);
  final watchReads = ref.watch(watchReadsFnProvider(chatId));
  final uid = ref.watch(readReceiptUserIdProvider);
  bool current() =>
      ref.mounted &&
      ref.read(readReceiptsEnabledProvider) &&
      ref.read(readReceiptUserIdProvider) == uid;
  Set<String> ids(List<Map<String, dynamic>> rows) => rows
      .where((r) => r['receipt_visible'] != false)
      .where((r) => r['user_id'] != uid)
      .map((r) => r['message_id'] as String)
      .toSet();
  final cache = uid == null ? null : LocalChatSignalsCache(uid, chatId);
  final saved = await cache?.read('reads') ?? <Map<String, dynamic>>[];
  var lastRows = saved;
  if (!current()) return;
  if (saved.isNotEmpty) yield ids(saved);
  try {
    await for (final rows in watchReads()) {
      if (!current()) return;
      lastRows = rows;
      yield ids(rows);
      await cache?.save('reads', rows);
    }
  } catch (_) {
    if (current()) yield ids(lastRows);
  }
});
