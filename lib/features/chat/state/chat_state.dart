import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/data/chat_mappers.dart';
import '../../../shared/data/languages.dart';
import '../../../shared/models/message.dart';
import '../../../shared/state/auth_state.dart';
import '../../../shared/state/chat_list_state.dart';
import '../../../shared/state/connectivity_state.dart';
import 'pending_sends_state.dart';

/// Dev/QA toggle: when `true`, every outgoing send is simulated to fail
/// (PRD US-030 affordances). Currently unwired pending Task 12 (optimistic
/// pending queue + real failure path). Kept for the dev menu switch.
class SimulateFailureNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool value) => state = value;
}

final simulateFailureProvider =
    NotifierProvider<SimulateFailureNotifier, bool>(
  SimulateFailureNotifier.new,
);

/// Per-chat message stream backed by Supabase. Yields a one-shot history
/// from [ChatService.fetchMessages] followed by realtime snapshots from
/// [ChatService.watchMessages]. PRD US-013…US-017, US-023.
class ChatNotifier extends StreamNotifier<List<Message>> {
  ChatNotifier(this.chatId);

  final String chatId;

  /// Ids currently being sent to the server. Guards against a queued send
  /// being fired twice when both the user action and the reconnect flush
  /// race on the same message.
  final Set<String> _inFlight = <String>{};

  bool get _online => ref.read(isOnlineProvider);

  String get _uid {
    final id = Supabase.instance.client.auth.currentUser?.id;
    if (id == null) throw StateError('not_signed_in');
    return id;
  }

  @override
  Stream<List<Message>> build() async* {
    ref.watch(authSessionProvider);
    final svc = ref.watch(chatServiceProvider);
    try {
      final history = await svc.fetchMessages(chatId);
      yield history;
    } catch (_) {
      // Offline / fetch failure: don't yield anything. Riverpod keeps the
      // previous AsyncData accessible via `.value`, so the chat screen
      // continues to show the last-known messages instead of an empty list.
    }
    try {
      await for (final rows in svc.watchMessages(chatId)) {
        final list = rows
            .where((r) => r['deleted_at'] == null)
            .map((r) => messageFromRow(r, currentUserId: _uid))
            .toList();
        yield list;
      }
    } catch (_) {
      // Realtime errored (e.g. offline). Keep last yielded state.
    }
  }

  /// Send a new outgoing message. Lays an optimistic pending bubble into
  /// [pendingSendsProvider]. When offline the bubble stays queued (clock)
  /// and the reconnect flush sends it later; when online it's sent right
  /// away. Step 2.2 Task 12 / PRD US-016, US-021, US-030, US-031.
  Future<void> addOutgoing(String text, {Message? replyTo}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final tempId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final pending = Message(
      id: tempId,
      chatId: chatId,
      isOutgoing: true,
      originalText: trimmed,
      translation: '',
      sentAt: DateTime.now(),
      status: MessageStatus.pending,
      replyTo: replyTo,
    );
    ref.read(pendingSendsProvider(chatId).notifier).add(pending);
    // Offline: leave it on the clock. [flushPending] retries on reconnect.
    if (!_online) return;
    await _attemptSend(tempId, trimmed);
  }

  /// Push one queued message to the server. On success the pending row is
  /// upgraded in place (clock → tick) keeping its widget identity; the
  /// realtime stream later dedupes it by the server id. On error, a
  /// genuine server rejection (still online) flips the row to
  /// [MessageStatus.failed] so the user gets the retry sheet, while a
  /// network drop mid-send leaves it queued for the next reconnect flush.
  Future<void> _attemptSend(String localId, String body) async {
    if (_inFlight.contains(localId)) return;
    _inFlight.add(localId);
    try {
      // Dev/QA: the dev-menu "failed-send" switch forces a server-side
      // rejection so US-030's ⚠ + retry path can be exercised on a real
      // device without a genuine outage.
      if (ref.read(simulateFailureProvider)) {
        throw Exception('simulated_failure');
      }
      final server = await ref
          .read(chatServiceProvider)
          .sendMessage(chatId: chatId, body: body);
      ref.read(pendingSendsProvider(chatId).notifier).upgrade(
            tempId: localId,
            newId: server.id,
            newSentAt: server.createdAt,
          );
      // Refresh chat list so the tile's last-message preview updates.
      ref.read(chatListProvider.notifier).refresh();
    } catch (_) {
      if (_online) {
        ref.read(pendingSendsProvider(chatId).notifier).update(
              localId,
              (m) => m.copyWith(status: MessageStatus.failed),
            );
      }
      // Offline drop: keep the row pending so the reconnect flush retries.
    } finally {
      _inFlight.remove(localId);
    }
  }

  /// Re-attempt every still-pending queued send for this chat. Triggered
  /// when connectivity returns and on chat open, so sends interrupted by
  /// going offline or by an app kill go out automatically. No-op while
  /// offline. PRD US-030, US-031.
  Future<void> flushPending() async {
    if (!_online) return;
    final queued = ref
        .read(pendingSendsProvider(chatId))
        .where((m) => m.status == MessageStatus.pending)
        .toList();
    for (final m in queued) {
      await _attemptSend(m.id, m.originalText);
    }
  }

  /// Re-fire a previously failed send. Drops the failed row from the
  /// queue, then routes back through [addOutgoing] (which lays down a
  /// fresh pending row). PRD US-030.
  Future<void> retryFailed(String localId) async {
    final pendings = ref.read(pendingSendsProvider(chatId));
    Message? target;
    for (final m in pendings) {
      if (m.id == localId) {
        target = m;
        break;
      }
    }
    if (target == null) return;
    ref.read(pendingSendsProvider(chatId).notifier).remove(localId);
    await addOutgoing(target.originalText, replyTo: target.replyTo);
  }

  /// Drop a pending or failed message from the queue without retrying.
  /// Used by the failed-message sheet's "Delete" action. PRD US-030.
  void dropPending(String localId) {
    ref.read(pendingSendsProvider(chatId).notifier).remove(localId);
  }

  /// Edit an existing outgoing message. PRD US-019.
  Future<void> editMessage(String id, String newText) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;
    await ref
        .read(chatServiceProvider)
        .editMessage(messageId: id, newBody: trimmed);
  }

  /// Soft-delete a message. Paired with [restoreMessage] for Undo. PRD
  /// US-019.
  Future<void> removeMessage(String id) async {
    await ref.read(chatServiceProvider).softDelete(id);
  }

  /// Undo a soft-delete by nulling `deleted_at` on the row. PRD US-019.
  Future<void> restoreMessage(String id) async {
    await ref.read(chatServiceProvider).restoreMessage(id);
  }
}

final chatMessagesProvider =
    StreamNotifierProvider.family<ChatNotifier, List<Message>, String>(
  ChatNotifier.new,
);

/// Per-chat translation visibility. Default `true`. Flipping this only
/// affects the chat with the matching `chatId` — PRD FR-23.
class ShowTranslationsNotifier extends Notifier<bool> {
  ShowTranslationsNotifier(this.chatId);

  final String chatId;

  @override
  bool build() => true;

  void toggle() => state = !state;
}

final showTranslationsProvider =
    NotifierProvider.family<ShowTranslationsNotifier, bool, String>(
  ShowTranslationsNotifier.new,
);

/// Per-chat "currently replying to" message. Null when not replying.
/// Setting a reply target clears any in-flight edit (the two modes are
/// mutually exclusive). PRD US-021.
class ReplyingToNotifier extends Notifier<Message?> {
  ReplyingToNotifier(this.chatId);

  final String chatId;

  @override
  Message? build() => null;

  void set(Message m) {
    // Cancel an in-flight edit when replying.
    ref.read(editingProvider(chatId).notifier).clear();
    state = m;
  }

  void clear() {
    state = null;
  }
}

final replyingToProvider =
    NotifierProvider.family<ReplyingToNotifier, Message?, String>(
  ReplyingToNotifier.new,
);

/// Per-chat "currently editing" message. Null when not editing. PRD US-019.
class EditingNotifier extends Notifier<Message?> {
  EditingNotifier(this.chatId);

  final String chatId;

  @override
  Message? build() => null;

  void set(Message m) {
    // Cancel an in-flight reply when editing.
    ref.read(replyingToProvider(chatId).notifier).clear();
    state = m;
  }

  void clear() {
    state = null;
  }
}

final editingProvider =
    NotifierProvider.family<EditingNotifier, Message?, String>(
  EditingNotifier.new,
);

/// Per-chat learning language. Seeded from the live chat list — when the
/// chat row is present we use its `learningLanguage`, otherwise we fall
/// back to English. Mutating this updates only the chat with the matching
/// `chatId`. PRD US-022 / US-028.
class LearningLanguageNotifier extends Notifier<BlabLanguage> {
  LearningLanguageNotifier(this.chatId);

  final String chatId;

  @override
  BlabLanguage build() {
    final english = kBlabLanguages.firstWhere((l) => l.code == 'en');
    final chats = ref.watch(chatListProvider).value;
    if (chats == null) return english;
    for (final c in chats) {
      if (c.id == chatId) return c.learningLanguage;
    }
    return english;
  }

  /// Optimistically updates local state and persists the new language to
  /// the user's `chat_members` row. The persist call survives realtime
  /// refreshes of `chatListProvider`. On failure the change is rolled
  /// back to the prior language and the error rethrown so the caller can
  /// surface it.
  Future<void> set(BlabLanguage lang) async {
    final previous = state;
    state = lang;
    try {
      await ref
          .read(chatServiceProvider)
          .setLearningLanguage(chatId: chatId, langCode: lang.code);
      await ref.read(chatListProvider.notifier).refresh();
    } catch (e) {
      state = previous;
      rethrow;
    }
  }
}

final learningLanguageProvider =
    NotifierProvider.family<LearningLanguageNotifier, BlabLanguage, String>(
  LearningLanguageNotifier.new,
);
