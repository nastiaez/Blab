import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../shared/data/chat_mappers.dart';
import '../../../shared/data/languages.dart';
import '../../../shared/models/message.dart';
import '../../../shared/state/auth_state.dart';
import '../../../shared/services/portfolio_translator.dart';
import '../../../shared/state/chat_list_state.dart';
import '../../../shared/state/portfolio_messages_state.dart';
import '../../../shared/state/portfolio_mode.dart';
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

  String get _uid {
    final id = Supabase.instance.client.auth.currentUser?.id;
    if (id == null) throw StateError('not_signed_in');
    return id;
  }

  @override
  Stream<List<Message>> build() async* {
    if (ref.watch(portfolioModeProvider)) {
      yield ref.watch(portfolioMessagesProvider(chatId));
      return;
    }
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
  /// [pendingSendsProvider], then awaits the real send. On success the
  /// pending row is dropped (the realtime stream will deliver the canonical
  /// row); on failure the row's status flips to [MessageStatus.failed] and
  /// stays in the queue so the user can retry from the failed-message
  /// sheet. Step 2.2 Task 12 / PRD US-016, US-021, US-030, US-031.
  Future<void> addOutgoing(String text, {Message? replyTo}) async {
    if (ref.read(portfolioModeProvider)) {
      await _addOutgoingPortfolio(text, replyTo: replyTo);
      return;
    }
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
    try {
      final server = await ref
          .read(chatServiceProvider)
          .sendMessage(chatId: chatId, body: trimmed);
      // In-place upgrade: swap the temp id + sentAt for the server's values
      // and flip status to delivered. The bubble keeps its position; only
      // the clock icon turns into a tick. When the realtime stream emits
      // the canonical row, the merge layer dedupes by id and the pending
      // entry quietly drops away with no visual jump.
      ref.read(pendingSendsProvider(chatId).notifier).upgrade(
            tempId: tempId,
            newId: server.id,
            newSentAt: server.createdAt,
          );
      // Refresh chat list so the tile's last-message preview updates
      // immediately.
      ref.read(chatListProvider.notifier).refresh();
    } catch (_) {
      ref.read(pendingSendsProvider(chatId).notifier).update(
            tempId,
            (m) => m.copyWith(status: MessageStatus.failed),
          );
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
    if (ref.read(portfolioModeProvider)) return;
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;
    await ref
        .read(chatServiceProvider)
        .editMessage(messageId: id, newBody: trimmed);
  }

  /// Soft-delete a message. Paired with [restoreMessage] for Undo. PRD
  /// US-019.
  Future<void> removeMessage(String id) async {
    if (ref.read(portfolioModeProvider)) return;
    await ref.read(chatServiceProvider).softDelete(id);
  }

  /// Undo a soft-delete by nulling `deleted_at` on the row. PRD US-019.
  Future<void> restoreMessage(String id) async {
    if (ref.read(portfolioModeProvider)) return;
    await ref.read(chatServiceProvider).restoreMessage(id);
  }

  Future<void> _addOutgoingPortfolio(String text, {Message? replyTo}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final id = 'portfolio-${DateTime.now().microsecondsSinceEpoch}';
    final pending = Message(
      id: id,
      chatId: chatId,
      isOutgoing: true,
      originalText: trimmed,
      translation: '',
      sentAt: DateTime.now(),
      status: MessageStatus.delivered,
      replyTo: replyTo,
      translationState: TranslationState.pending,
    );
    final messages =
        ref.read(portfolioMessagesProvider(chatId).notifier);
    messages.append(pending);

    // Optimistic delivered → read flip, mirrors the curated outgoing
    // bubbles in portfolio_data.dart.
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      messages.updateById(id, (m) => m.copyWith(status: MessageStatus.read));
    });

    try {
      final result =
          await ref.read(portfolioTranslatorProvider).translate(trimmed);
      messages.updateById(
        id,
        (m) => m.copyWith(
          translation: result.tamil,
          tokens: result.tokens,
          clearTranslationState: true,
        ),
      );
    } on PortfolioTranslationFailed {
      messages.updateById(
        id,
        (m) => m.copyWith(translationState: TranslationState.unavailable),
      );
    }
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

  void set(BlabLanguage lang) {
    state = lang;
  }
}

final learningLanguageProvider =
    NotifierProvider.family<LearningLanguageNotifier, BlabLanguage, String>(
  LearningLanguageNotifier.new,
);
