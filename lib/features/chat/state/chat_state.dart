import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/languages.dart';
import '../../../shared/models/chat.dart';
import '../../../shared/models/message.dart';
import '../../../shared/services/chat_service.dart';
import '../../../shared/services/local_chat_history_cache.dart';
import '../../../shared/state/auth_state.dart';
import '../../../shared/state/chat_list_state.dart';
import '../../../shared/state/connectivity_state.dart';
import 'unread_chat_state.dart';
import 'pending_sends_state.dart';
import 'form_correction_state.dart';

/// Dev/QA one-shot: when armed, the next outgoing send is simulated to fail
/// so PRD US-030's retry/delete affordances can be exercised deterministically.
class SimulateFailureNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void set(bool value) => state = value;

  /// Consume the debug failure once so the resulting bubble can be retried
  /// without navigating back to the dev menu to reset the switch.
  bool consume() {
    if (!state) return false;
    state = false;
    return true;
  }
}

final simulateFailureProvider = NotifierProvider<SimulateFailureNotifier, bool>(
  SimulateFailureNotifier.new,
);

typedef ClientMessageIdFactory = String Function();

final clientMessageIdFactoryProvider = Provider<ClientMessageIdFactory>(
  (ref) => _newClientMessageId,
);

String _newClientMessageId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

class ChatPaginationState {
  const ChatPaginationState({required this.hasMore, required this.isLoading});

  const ChatPaginationState.initial() : hasMore = false, isLoading = false;

  final bool hasMore;
  final bool isLoading;
}

class ChatPaginationNotifier extends Notifier<ChatPaginationState> {
  ChatPaginationNotifier(this.chatId);

  final String chatId;

  @override
  ChatPaginationState build() => const ChatPaginationState.initial();

  void update({required bool hasMore, required bool isLoading}) {
    state = ChatPaginationState(hasMore: hasMore, isLoading: isLoading);
  }
}

final chatPaginationProvider =
    NotifierProvider.family<
      ChatPaginationNotifier,
      ChatPaginationState,
      String
    >(ChatPaginationNotifier.new);

/// Per-chat message stream backed by a cursor-bounded history fetch and
/// individual Supabase realtime changes. PRD US-013…US-017, US-023.
class ChatNotifier extends StreamNotifier<List<Message>> {
  ChatNotifier(this.chatId);

  static const int pageSize = 50;

  final String chatId;
  final Map<String, Message> _messagesById = <String, Message>{};
  MessageCursor? _oldestCursor;
  bool _hasMore = false;
  bool _loadingOlder = false;

  /// Ids currently being sent to the server. Guards against a queued send
  /// being fired twice when both the user action and the reconnect flush
  /// race on the same message.
  final Set<String> _inFlight = <String>{};

  bool get _online => ref.read(isOnlineProvider);

  List<Message> _snapshot() {
    final result = _messagesById.values.toList()
      ..sort((a, b) {
        final byTime = a.sentAt.compareTo(b.sentAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
    return result;
  }

  void _setPagination({bool? loading}) {
    _loadingOlder = loading ?? _loadingOlder;
    final nextHasMore = _hasMore;
    final nextIsLoading = _loadingOlder;
    // Riverpod forbids mutating a sibling provider synchronously while this
    // StreamNotifier is building. Publish metadata on the next microtask.
    Future<void>.microtask(() {
      try {
        ref
            .read(chatPaginationProvider(chatId).notifier)
            .update(hasMore: nextHasMore, isLoading: nextIsLoading);
      } catch (_) {
        // The chat may have been disposed before the microtask runs.
      }
    });
  }

  void _reconcilePending(List<Message> messages) {
    final ids = messages.map((message) => message.id).toList();
    Future<void>.microtask(() {
      try {
        ref.read(pendingSendsProvider(chatId).notifier).reconcile(ids);
        unawaited(
          ref
              .read(formCorrectionProvider.notifier)
              .observe(chatId, messages)
              .catchError((Object _) {}),
        );
      } catch (_) {
        // The chat may have been disposed before the microtask runs.
      }
    });
  }

  @override
  Stream<List<Message>> build() async* {
    ref.watch(currentUserIdProvider);
    final svc = ref.watch(chatServiceProvider);
    final localCache = ref.watch(localChatHistoryCacheProvider);
    _messagesById.clear();
    _oldestCursor = null;
    _hasMore = false;
    _setPagination(loading: false);

    final cached = await localCache?.loadMessages(chatId) ?? const [];
    if (cached.isNotEmpty) {
      for (final message in cached) {
        _messagesById[message.id] = message;
      }
      final snapshot = _snapshot();
      _reconcilePending(snapshot);
      yield snapshot;
    }

    try {
      final page = await svc.fetchMessagePage(chatId, limit: pageSize);
      _messagesById.clear();
      for (final message in page.messages) {
        _messagesById[message.id] = message;
      }
      _oldestCursor = page.nextCursor;
      _hasMore = page.hasMore;
      _setPagination();
      final snapshot = _snapshot();
      _reconcilePending(snapshot);
      unawaited(localCache?.saveMessages(chatId, snapshot));
      yield snapshot;
    } catch (error, stackTrace) {
      // A recovered snapshot stays readable while realtime reconnects. With
      // no snapshot, surface the initial failure so the chat can offer Retry
      // instead of remaining on skeletons forever (US-032).
      if (cached.isEmpty) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
    try {
      await for (final change in svc.watchMessageChanges(chatId)) {
        try {
          switch (change.type) {
            case MessageChangeType.upsert:
              final message = await svc.messageFromRealtimeRow(change.row!);
              if (message != null) _messagesById[message.id] = message;
              break;
            case MessageChangeType.remove:
              final id = change.row?['id'];
              if (id is String) {
                _messagesById.remove(id);
                unawaited(
                  ref
                      .read(formCorrectionProvider.notifier)
                      .mutate((s) => s.removeMessage(chatId, id))
                      .catchError((Object _) {}),
                );
              }
              break;
            case MessageChangeType.resync:
              final loadedCount = _messagesById.length < pageSize
                  ? pageSize
                  : _messagesById.length;
              final page = await svc.fetchMessagePage(
                chatId,
                limit: loadedCount,
              );
              _messagesById
                ..clear()
                ..addEntries(page.messages.map((m) => MapEntry(m.id, m)));
              _oldestCursor = page.nextCursor;
              _hasMore = page.hasMore;
              _setPagination();
              break;
          }
        } catch (_) {
          // Keep the channel alive. A later event or reconnect resync can
          // repair a transient PostgREST failure for this one change.
          continue;
        }
        final snapshot = _snapshot();
        _reconcilePending(snapshot);
        unawaited(localCache?.saveMessages(chatId, snapshot));
        yield snapshot;
      }
    } catch (_) {
      // Realtime errored (e.g. offline). Keep last yielded state.
    }
  }

  /// Loads the next older page once. Concurrent edge notifications collapse
  /// into the same request and cursor ordering prevents insert races from
  /// skipping or duplicating history.
  Future<void> loadOlder() async {
    if (_loadingOlder || !_hasMore || _oldestCursor == null) return;
    _setPagination(loading: true);
    try {
      final page = await ref
          .read(chatServiceProvider)
          .fetchMessagePage(chatId, limit: pageSize, before: _oldestCursor);
      for (final message in page.messages) {
        _messagesById[message.id] = message;
      }
      _oldestCursor = page.nextCursor ?? _oldestCursor;
      _hasMore = page.hasMore;
      final snapshot = _snapshot();
      _reconcilePending(snapshot);
      unawaited(
        ref.read(localChatHistoryCacheProvider)?.saveMessages(chatId, snapshot),
      );
      state = AsyncData(snapshot);
    } catch (_) {
      // Keep the current page and allow another edge hit to retry.
    } finally {
      _setPagination(loading: false);
    }
  }

  /// Send a new outgoing message. Lays an optimistic pending bubble into
  /// [pendingSendsProvider]. When offline the bubble stays queued (clock)
  /// and the reconnect flush sends it later; when online it's sent right
  /// away. Step 2.2 Task 12 / PRD US-016, US-021, US-030, US-031.
  Future<void> addOutgoing(String text, {Message? replyTo}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final tempId = ref.read(clientMessageIdFactoryProvider)();
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
    await ref
        .read(formCorrectionProvider.notifier)
        .closeChat(chatId)
        .catchError((Object _) {});
    // Offline: leave it on the clock. [flushPending] retries on reconnect.
    if (!_online) return;
    await _attemptSend(tempId, trimmed, replyToId: replyTo?.id);
  }

  Future<void> addOutgoingPhoto(
    PickedChatImage image, {
    String caption = '',
    Message? replyTo,
  }) async {
    final trimmed = caption.trim();
    final tempId = ref.read(clientMessageIdFactoryProvider)();
    final pending = Message(
      id: tempId,
      chatId: chatId,
      isOutgoing: true,
      originalText: trimmed,
      translation: '',
      sentAt: DateTime.now(),
      status: MessageStatus.pending,
      type: MessageType.image,
      attachment: MessageAttachment(
        id: tempId,
        messageId: tempId,
        chatId: chatId,
        storageBucket: 'message-media',
        storagePath: '',
        mimeType: image.mimeType,
        byteSize: image.bytes.length,
        localBytes: image.bytes,
      ),
      replyTo: replyTo,
    );
    ref.read(pendingSendsProvider(chatId).notifier).add(pending);
    await ref
        .read(formCorrectionProvider.notifier)
        .closeChat(chatId)
        .catchError((Object _) {});
    if (!_online) {
      ref
          .read(pendingSendsProvider(chatId).notifier)
          .update(tempId, (m) => m.copyWith(status: MessageStatus.failed));
      return;
    }
    await _attemptSendPhoto(
      tempId,
      image,
      caption: trimmed,
      replyToId: replyTo?.id,
    );
  }

  /// Push one queued message to the server. On success the pending row is
  /// upgraded in place (clock → tick) keeping its widget identity; the
  /// realtime stream later dedupes it by the server id. On error, a
  /// genuine server rejection (still online) flips the row to
  /// [MessageStatus.failed] so the user gets the retry sheet, while a
  /// network drop mid-send leaves it queued for the next reconnect flush.
  Future<void> _attemptSend(
    String localId,
    String body, {
    String? replyToId,
  }) async {
    if (_inFlight.contains(localId)) return;
    if (!_online) return;
    _inFlight.add(localId);
    var simulatedFailure = false;
    try {
      // Dev/QA: consume the one-shot before forcing a rejection so the
      // resulting failed bubble can exercise the real retry path.
      if (ref.read(simulateFailureProvider.notifier).consume()) {
        simulatedFailure = true;
        throw Exception('simulated_failure');
      }
      final server = await ref
          .read(chatServiceProvider)
          .sendMessage(
            chatId: chatId,
            body: body,
            clientMessageId: localId,
            replyToId: replyToId,
          );
      ref
          .read(pendingSendsProvider(chatId).notifier)
          .upgrade(
            tempId: localId,
            newId: server.id,
            newSentAt: server.createdAt,
          );
      // Refresh chat list so the tile's last-message preview updates.
      ref.read(chatListProvider.notifier).refresh();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Message send failed: type=${error.runtimeType}, error=$error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      final backendReachable =
          simulatedFailure ||
          await ref.read(backendReachabilityCheckProvider)();
      if (backendReachable) {
        ref
            .read(pendingSendsProvider(chatId).notifier)
            .update(localId, (m) => m.copyWith(status: MessageStatus.failed));
      } else {
        // Re-run the online stream now instead of waiting for its periodic
        // probe; this also updates the banner for offline Wi-Fi immediately.
        ref.invalidate(onlineProvider);
      }
      // Offline drop: keep the row pending so the reconnect flush retries.
    } finally {
      _inFlight.remove(localId);
    }
  }

  Future<void> _attemptSendPhoto(
    String localId,
    PickedChatImage image, {
    required String caption,
    String? replyToId,
  }) async {
    if (_inFlight.contains(localId)) return;
    if (!_online) return;
    _inFlight.add(localId);
    var simulatedFailure = false;
    try {
      if (ref.read(simulateFailureProvider.notifier).consume()) {
        simulatedFailure = true;
        throw Exception('simulated_failure');
      }
      final server = await ref
          .read(chatServiceProvider)
          .sendPhotoMessage(
            chatId: chatId,
            image: image,
            caption: caption,
            clientMessageId: localId,
            replyToId: replyToId,
          );
      ref
          .read(pendingSendsProvider(chatId).notifier)
          .upgrade(
            tempId: localId,
            newId: server.id,
            newSentAt: server.createdAt,
            attachment: server.attachment,
          );
      ref.read(chatListProvider.notifier).refresh();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          'Photo send failed: type=${error.runtimeType}, error=$error',
        );
        debugPrintStack(stackTrace: stackTrace);
      }
      final backendReachable =
          simulatedFailure ||
          await ref.read(backendReachabilityCheckProvider)();
      if (backendReachable) {
        ref
            .read(pendingSendsProvider(chatId).notifier)
            .update(localId, (m) => m.copyWith(status: MessageStatus.failed));
      } else {
        ref.invalidate(onlineProvider);
      }
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
      if (m.type == MessageType.image) {
        final bytes = m.attachment?.localBytes;
        if (bytes == null) {
          ref
              .read(pendingSendsProvider(chatId).notifier)
              .update(
                m.id,
                (message) => message.copyWith(status: MessageStatus.failed),
              );
          continue;
        }
        await _attemptSendPhoto(
          m.id,
          PickedChatImage(
            bytes: Uint8List.fromList(bytes),
            mimeType: m.attachment!.mimeType,
            fileName: m.attachment!.storagePath.split('/').last,
          ),
          caption: m.originalText,
          replyToId: m.replyTo?.id,
        );
      } else {
        await _attemptSend(m.id, m.originalText, replyToId: m.replyTo?.id);
      }
    }
  }

  /// Re-fire a previously failed send with its original idempotency id.
  /// PRD US-030.
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
    ref
        .read(pendingSendsProvider(chatId).notifier)
        .update(
          localId,
          (message) => message.copyWith(status: MessageStatus.pending),
        );
    if (target.type == MessageType.image) {
      final bytes = target.attachment?.localBytes;
      if (bytes == null) {
        ref
            .read(pendingSendsProvider(chatId).notifier)
            .update(localId, (m) => m.copyWith(status: MessageStatus.failed));
        return;
      }
      await _attemptSendPhoto(
        localId,
        PickedChatImage(
          bytes: Uint8List.fromList(bytes),
          mimeType: target.attachment!.mimeType,
          fileName: target.attachment!.storagePath.split('/').last,
        ),
        caption: target.originalText,
        replyToId: target.replyTo?.id,
      );
    } else {
      await _attemptSend(
        localId,
        target.originalText,
        replyToId: target.replyTo?.id,
      );
    }
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
    await ref
        .read(formCorrectionProvider.notifier)
        .mutate((s) => s.removeMessage(chatId, id))
        .catchError((Object _) {});
  }

  /// Soft-delete a message. Hides it locally right away (so it disappears
  /// the instant the user taps Delete, regardless of realtime timing), then
  /// persists the soft-delete server-side. If the server call fails, the
  /// optimistic hide is rolled back so we never pretend a message is gone
  /// when it isn't. Also drops it from the pending queue in case it was an
  /// un-acknowledged send. Paired with [restoreMessage] for Undo. PRD US-019.
  Future<void> removeMessage(String id) async {
    ref.read(hiddenMessagesProvider(chatId).notifier).hide(id);
    ref.read(pendingSendsProvider(chatId).notifier).remove(id);
    try {
      await ref.read(chatServiceProvider).softDelete(id);
      await ref
          .read(formCorrectionProvider.notifier)
          .mutate((s) => s.removeMessage(chatId, id))
          .catchError((Object _) {});
    } catch (_) {
      ref.read(hiddenMessagesProvider(chatId).notifier).unhide(id);
      rethrow;
    }
  }

  /// Undo a soft-delete: un-hide locally and null `deleted_at` server-side.
  /// PRD US-019.
  Future<void> restoreMessage(String id) async {
    ref.read(hiddenMessagesProvider(chatId).notifier).unhide(id);
    await ref.read(chatServiceProvider).restoreMessage(id);
  }
}

/// Ids optimistically hidden by a local delete, per chat. Overlaid on top
/// of the realtime message list so a delete (and its Undo) feels instant
/// and doesn't depend on the realtime row update arriving first. PRD
/// US-019.
class HiddenMessagesNotifier extends Notifier<Set<String>> {
  HiddenMessagesNotifier(this.chatId);

  final String chatId;

  @override
  Set<String> build() => <String>{};

  void hide(String id) => state = {...state, id};
  void unhide(String id) => state = {...state}..remove(id);
}

final hiddenMessagesProvider =
    NotifierProvider.family<HiddenMessagesNotifier, Set<String>, String>(
      HiddenMessagesNotifier.new,
    );

final chatMessagesProvider =
    StreamNotifierProvider.family<ChatNotifier, List<Message>, String>(
      ChatNotifier.new,
    );

/// Per-chat mode (practice vs. normal). Seeded from the live chat list —
/// when the chat row is present we use its `mode`, otherwise we default to
/// `ChatMode.practice`. Mutating this updates only the chat with the
/// matching `chatId`. PRD FR-23.
class ChatModeNotifier extends Notifier<ChatMode> {
  ChatModeNotifier(this.chatId);
  final String chatId;

  @override
  ChatMode build() {
    final chats = ref.watch(chatListProvider).value;
    if (chats == null) return ChatMode.practice;
    for (final c in chats) {
      if (c.id == chatId) return c.mode;
    }
    return ChatMode.practice;
  }

  /// Optimistically flips local state before the network call resolves —
  /// unlike [LearningLanguageNotifier], which sets state only after
  /// success — so the mode toggle feels instant. On failure the change is
  /// rolled back to the prior mode and the error rethrown so the caller
  /// can surface it.
  Future<void> set(ChatMode mode) async {
    final previous = state;
    state = mode; // optimistic — the toggle should feel instant
    try {
      await ref
          .read(chatServiceProvider)
          .setChatMode(chatId: chatId, mode: mode);
      await ref.read(chatListProvider.notifier).refresh();
    } catch (e) {
      state = previous;
      rethrow;
    }
  }
}

final chatModeProvider =
    NotifierProvider.family<ChatModeNotifier, ChatMode, String>(
      ChatModeNotifier.new,
    );

/// Per-chat "collapse everything" bump counter. [ModeToggle] increments this
/// the instant the user switches mode — before the [ChatModeNotifier.set]
/// network call resolves — so widgets watching it (bubble expand/collapse
/// state, the word popup) can reset in lockstep with the mode switch rather
/// than waiting on the network. The value itself is meaningless; only
/// changes to it matter. PRD FR-23.
class ChatModeResetSignalNotifier extends Notifier<int> {
  ChatModeResetSignalNotifier(this.chatId);
  final String chatId;
  @override
  int build() => 0;
  void bump() => state++;
}

final chatModeResetSignalProvider =
    NotifierProvider.family<ChatModeResetSignalNotifier, int, String>(
      ChatModeResetSignalNotifier.new,
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
    try {
      await ref
          .read(chatServiceProvider)
          .setLearningLanguage(chatId: chatId, langCode: lang.code)
          .timeout(const Duration(seconds: 12));
      ref
          .read(chatListProvider.notifier)
          .confirmPracticeLanguageSelection(chatId, lang);
      state = lang;
      ref.invalidate(chatLanguageTimelineProvider(chatId));
      unawaited(ref.read(chatListProvider.notifier).refresh());
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
