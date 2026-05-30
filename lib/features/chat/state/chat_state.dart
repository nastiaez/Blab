import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/data/languages.dart';
import '../../../shared/data/mock_chats.dart';
import '../../../shared/data/mock_messages.dart';
import '../../../shared/models/message.dart';

/// Dev/QA toggle: when `true`, every outgoing send is simulated to fail
/// (PRD US-030 affordances). The chat input still works — the resulting
/// bubble just lands in [MessageStatus.failed] so the retry UI is reachable
/// without a real backend.
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

/// Per-chat message store. Seeded with mock data, mutated locally only.
///
/// Step 2.2 will replace this with a real Supabase-backed stream.
class ChatNotifier extends Notifier<List<Message>> {
  ChatNotifier(this.chatId);

  final String chatId;

  @override
  List<Message> build() {
    return mockMessagesFor(chatId);
  }

  /// Append an outgoing message. Starts in [MessageStatus.delivered] and
  /// flips to [MessageStatus.read] after a 1500 ms delay so the read-tick
  /// transition is observable. PRD US-016.
  ///
  /// When the global [simulateFailureProvider] is on, the message instead
  /// starts in [MessageStatus.pending] and flips to [MessageStatus.failed]
  /// after 800 ms — used to demo the retry sheet. PRD US-030 affordances.
  ///
  /// Optionally threads a quoted [replyTo] message into the bubble — PRD
  /// US-021.
  void addOutgoing(String text, {Message? replyTo}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final shouldFail = ref.read(simulateFailureProvider);

    final now = DateTime.now();
    final newMessage = Message(
      id: 'local-${now.microsecondsSinceEpoch}',
      chatId: chatId,
      isOutgoing: true,
      originalText: trimmed,
      translation: '',
      sentAt: now,
      status: shouldFail ? MessageStatus.pending : MessageStatus.delivered,
      replyTo: replyTo,
    );
    state = [...state, newMessage];

    if (shouldFail) {
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (!ref.mounted) return;
        state = [
          for (final m in state)
            if (m.id == newMessage.id)
              m.copyWith(status: MessageStatus.failed)
            else
              m,
        ];
      });
      return;
    }

    // BUG-008: use Future.delayed (not Timer) so the read-flip is scheduled
    // on the microtask/event loop deterministically — and run unconditionally
    // for every outgoing message regardless of the chat's seed state. The
    // earlier Timer-based path observably flipped to read instantly in the
    // empty `nastia` chat on Aswin's POV.
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      // Provider may have been disposed (user navigated away); guard.
      if (!ref.mounted) return;
      state = [
        for (final m in state)
          if (m.id == newMessage.id)
            m.copyWith(status: MessageStatus.read)
          else
            m,
      ];
    });
  }

  /// Retry a failed outgoing message: remove the failed bubble and re-queue
  /// a fresh send with the same text. PRD US-030 affordances.
  void retryFailed(String id) {
    final idx = state.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    final target = state[idx];
    if (!target.isOutgoing) return;
    // Drop the failed one, then re-fire addOutgoing so it goes through the
    // normal pending→delivered/read path (subject to simulateFailureProvider).
    state = [
      for (int i = 0; i < state.length; i++)
        if (i != idx) state[i],
    ];
    addOutgoing(target.originalText, replyTo: target.replyTo);
  }

  /// Edit an existing outgoing message in place. Marks it as edited so the
  /// bubble renders the "· edited" tag. PRD US-019.
  void editMessage(String id, String newText) {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;
    state = [
      for (final m in state)
        if (m.id == id) m.copyWith(originalText: trimmed, isEdited: true) else m,
    ];
  }

  /// Remove a message by id. Returns the index it was at, or `-1` if it
  /// wasn't in the list. The caller can pair this with [insertMessage] to
  /// implement Undo. PRD US-019.
  int removeMessage(String id) {
    final idx = state.indexWhere((m) => m.id == id);
    if (idx < 0) return -1;
    state = [
      for (int i = 0; i < state.length; i++)
        if (i != idx) state[i],
    ];
    return idx;
  }

  /// Insert a message at [index]. Clamps to `[0, state.length]`.
  void insertMessage(Message m, int index) {
    final clamped = index.clamp(0, state.length);
    final next = [...state];
    next.insert(clamped, m);
    state = next;
  }
}

final chatMessagesProvider =
    NotifierProvider.family<ChatNotifier, List<Message>, String>(
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

/// Per-chat learning language. Seeded from both POV chat lists via
/// [findChat] (falling back to English if the chat id is unknown).
/// Mutating this updates only the chat with the matching `chatId`.
/// PRD US-022 / US-028.
class LearningLanguageNotifier extends Notifier<BlabLanguage> {
  LearningLanguageNotifier(this.chatId);

  final String chatId;

  @override
  BlabLanguage build() {
    final chat = findChat(chatId);
    if (chat != null) return chat.learningLanguage;
    return kBlabLanguages.firstWhere((l) => l.code == 'en');
  }

  void set(BlabLanguage lang) {
    state = lang;
  }
}

final learningLanguageProvider =
    NotifierProvider.family<LearningLanguageNotifier, BlabLanguage, String>(
  LearningLanguageNotifier.new,
);
